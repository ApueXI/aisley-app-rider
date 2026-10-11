import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/domain/failed_delivery_attempt.dart';

void main() {
  for (final reason in FailedDeliveryReason.values) {
    test('exact authenticated JSON contract: ${reason.value}', () async {
      late http.Request request;
      final repo = repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(receipt(reason.value)), 201);
      });
      final result = await repo.reportFailedAttempt(
        taskId: 'task/private id',
        reason: reason,
        note: 'Building closed',
        expectedRevision: 7,
        idempotencyKey: '00000000-0000-4000-8000-000000000001',
      );
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/v1/courier/final-mile-tasks/task%2Fprivate%20id/failed-attempts',
      );
      expect(request.headers['authorization'], 'Bearer synthetic-token');
      expect(
        request.headers['idempotency-key'],
        '00000000-0000-4000-8000-000000000001',
      );
      expect(jsonDecode(request.body), {
        'reason': reason.value,
        'note': 'Building closed',
        'expected_revision': 7,
      });
      expect(result.attempt.reason, reason.value);
      expect(result.attempt.attemptedAt, DateTime.utc(2026, 10, 11, 9));
      expect(result.retryAllowed, isTrue);
    });
  }
  for (final malformed in <Object>[
    {},
    {'data': {}},
    {
      'data': {...receiptData, 'task_id': null},
    },
    {
      'data': {...receiptData, 'retry_allowed': 'true'},
    },
    {
      'data': {...receiptData, 'attempted_at': 'invalid'},
    },
    {
      'data': {...receiptData, 'note': 5},
    },
    {
      'data': {...receiptData, 'id': ''},
    },
    {
      'data': {...receiptData, 'reason': ''},
    },
  ]) {
    test(
      'malformed acknowledgment is an unconfirmed report: $malformed',
      () async {
        final repo = repository(
          (_) async => http.Response(jsonEncode(malformed), 201),
        );
        expect(
          repo.reportFailedAttempt(
            taskId: 'task-1',
            reason: FailedDeliveryReason.other,
            note: 'note',
            expectedRevision: 7,
            idempotencyKey: 'key',
          ),
          throwsA(isA<ApiContractException>()),
        );
      },
    );
  }
  test('unexpected successful HTTP status cannot confirm recording', () async {
    final repo = repository(
      (_) async => http.Response(jsonEncode(receipt('other')), 202),
    );
    expect(
      repo.reportFailedAttempt(
        taskId: 'task-1',
        reason: FailedDeliveryReason.other,
        note: 'note',
        expectedRevision: 7,
        idempotencyKey: 'key',
      ),
      throwsA(isA<ApiContractException>()),
    );
  });
  test('nullable note parses without inventing fields', () {
    final dto = FailedDeliveryAttemptReceipt.fromResponse({
      'data': {...receiptData, 'note': null},
    });
    expect(dto.attempt.note, isNull);
  });
  test('private history and frozen proof attempt count parse from current server fields', () {
    final context = DeliveryContext.fromResponse({
      'data': {
        'task_id': 'task-1',
        'status': 'out_for_delivery',
        'revision': 7,
        'failed_attempt_count': 12,
        'failed_attempts': [receiptData],
      },
    });
    final proof = CompletionProjection.fromResponse({
      'data': {
        'task_id': 'task-1',
        'task_status': 'out_for_delivery',
        'completion_status': null,
        'proof_failed_attempt_count': 11,
      },
    });
    expect(context.failedAttemptCount, 12);
    expect(context.failedAttempts.single.reasonLabel, 'Other');
    expect(proof.proofFailedAttemptCount, 11);
    expect(() => context.failedAttempts.clear(), throwsUnsupportedError);
  });
  for (final bad in <Object>[-1, '1', 1.5, true]) {
    test('invalid attempt count rejects malformed private state: $bad', () {
      expect(
        () => DeliveryContext.fromResponse({
          'data': {
            'task_id': 'task-1',
            'status': 'out_for_delivery',
            'failed_attempt_count': bad,
          },
        }),
        throwsA(isA<ApiContractException>()),
      );
      expect(
        () => CompletionProjection.fromResponse({
          'data': {
            'task_id': 'task-1',
            'task_status': 'out_for_delivery',
            'completion_status': null,
            'proof_failed_attempt_count': bad,
          },
        }),
        throwsA(isA<ApiContractException>()),
      );
    });
  }
  test('history rejects unbounded or malformed rows, accepts unknown read-only reasons', () {
    for (final rows in [
      List.filled(11, receiptData),
      [5],
    ]) {
      expect(
        () => DeliveryContext.fromResponse({
          'data': {
            'task_id': 'task-1',
            'status': 'out_for_delivery',
            'failed_attempts': rows,
          },
        }),
        throwsA(isA<ApiContractException>()),
      );
    }
    final row = FailedDeliveryAttempt.fromJson({
      ...receiptData,
      'reason': 'future_reason',
    });
    expect(row.reasonLabel, 'Other delivery attempt');
  });
  test('legacy missing counts remain unknown', () {
    expect(
      DeliveryContext.fromResponse({
        'data': {'task_id': 'task-1', 'status': 'out_for_delivery'},
      }).failedAttemptCount,
      isNull,
    );
  });
  for (final status in [401, 403, 404, 409, 422, 429, 503]) {
    test('HTTP $status remains a typed failure', () async {
      final repo = repository(
        (_) async => http.Response(
          jsonEncode({
            'code': 'TEST_ERROR',
            'message': 'private',
            'errors': {
              'note': ['Invalid note'],
            },
          }),
          status,
          headers: {'retry-after': '60'},
        ),
      );
      expect(
        repo.reportFailedAttempt(
          taskId: 'task-1',
          reason: FailedDeliveryReason.other,
          note: 'note',
          expectedRevision: 7,
          idempotencyKey: 'key',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', status)
              .having((e) => e.code, 'code', 'TEST_ERROR'),
        ),
      );
    });
  }
}

const receiptData = <String, dynamic>{
  'id': 'attempt-1',
  'task_id': 'task-1',
  'reason': 'other',
  'note': 'Building closed',
  'attempted_at': '2026-10-11T09:00:00Z',
  'retry_allowed': true,
};
Map<String, dynamic> receipt(String reason) => {
  'data': {...receiptData, 'reason': reason},
};
ApiDeliveryRepository repository(
  Future<http.Response> Function(http.Request) handler,
) => ApiDeliveryRepository(
  client: ApiClient(
    config: const AppConfig(baseUrl: 'https://api.example.test'),
    tokenStorage: _Storage(),
    client: MockClient(handler),
  ),
);

class _Storage implements TokenStorage {
  @override
  Future<String?> read() async => 'synthetic-token';
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}
