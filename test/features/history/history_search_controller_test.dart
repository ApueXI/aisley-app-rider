import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/history/domain/history_models.dart';
import 'package:aisley_app/features/history/presentation/controllers/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/history_search_fixture.dart';

void main() {
  late HistorySearchRepository repository;
  late HistoryController controller;
  setUp(() {
    repository = HistorySearchRepository();
    controller = HistoryController(historyRepository: repository);
  });
  tearDown(() => controller.dispose());

  test(
    'search forwards the exact trimmed reference through refresh and retry',
    () async {
      await controller.search('  Order-EXAMPLE / 42  ');
      await controller.load();
      repository.error = const ApiException.network('offline');
      await controller.load();
      expect(controller.status, HistoryLoadStatus.offline);
      expect(controller.items, isNotEmpty);
      repository.error = null;
      await controller.retry();
      expect(repository.references, List.filled(4, 'Order-EXAMPLE / 42'));
      expect(repository.limits, List.filled(4, 20));
      expect(controller.activeReference, 'Order-EXAMPLE / 42');
    },
  );

  test(
    'clear and blank submission load the unfiltered bounded history',
    () async {
      await controller.search('ORDER-A');
      await controller.clearSearch();
      await controller.search('ORDER-B');
      await controller.search('   ');
      expect(repository.references, ['ORDER-A', null, 'ORDER-B', null]);
      expect(controller.activeReference, isNull);
    },
  );

  test(
    'changed search clears rows and pagination before its response',
    () async {
      repository.page = DeliveryHistoryPage(
        items: [historyItem()],
        hasMore: true,
        nextCursor: 'opaque',
      );
      await controller.load();
      final pending = Completer<DeliveryHistoryPage>();
      repository.handler = (_) => pending.future;
      final search = controller.search('ORDER-B');
      expect(controller.items, isEmpty);
      expect(controller.hasMore, isFalse);
      expect(controller.nextCursor, isNull);
      pending.complete(const DeliveryHistoryPage(items: []));
      await search;
      expect(controller.status, HistoryLoadStatus.empty);
    },
  );

  test(
    'newest search wins out-of-order responses and obsolete failures',
    () async {
      final first = Completer<DeliveryHistoryPage>();
      final second = Completer<DeliveryHistoryPage>();
      final third = Completer<DeliveryHistoryPage>();
      repository.handler = (reference) => switch (reference) {
        'A' => first.future,
        'B' => second.future,
        _ => third.future,
      };
      final a = controller.search('A');
      final b = controller.search('B');
      final c = controller.search('C');
      third.complete(historyPage('C'));
      await c;
      second.completeError(
        const ApiException(
          statusCode: 401,
          code: 'UNAUTHENTICATED',
          message: 'expired',
        ),
      );
      await b;
      first.complete(historyPage('A'));
      await a;
      expect(controller.activeReference, 'C');
      expect(controller.items.single.order?.reference, 'C');
      expect(controller.status, HistoryLoadStatus.loaded);
      expect(controller.accountScopeGeneration, 0);
    },
  );

  test('clear during search invalidates the old result', () async {
    final pending = Completer<DeliveryHistoryPage>();
    repository.handler = (reference) async =>
        reference == null ? historyPage('UNFILTERED') : pending.future;
    final search = controller.search('A');
    await controller.clearSearch();
    pending.complete(historyPage('A'));
    await search;
    expect(controller.activeReference, isNull);
    expect(controller.items.single.order?.reference, 'UNFILTERED');
  });

  test(
    'policy recovery preserves the reference and hides protected rows',
    () async {
      await controller.search('ORDER-A');
      repository.error = const ApiException(
        statusCode: 403,
        code: 'POLICY_CONSENT_REQUIRED',
        message: 'accept policies',
      );
      await controller.load();
      expect(controller.status, HistoryLoadStatus.consentRequired);
      expect(controller.items, isEmpty);
      expect(controller.activeReference, 'ORDER-A');
      repository.error = null;
      await controller.load();
      expect(repository.references, ['ORDER-A', 'ORDER-A', 'ORDER-A']);
      expect(controller.status, HistoryLoadStatus.loaded);
    },
  );

  for (final error in [
    const ApiException(
      statusCode: 401,
      code: 'UNAUTHENTICATED',
      message: 'expired',
    ),
    const ApiException(
      statusCode: 403,
      code: 'LOGISTICS_ASSOCIATION_INVALID',
      message: 'denied',
    ),
    const ApiException(
      statusCode: 403,
      code: 'ACCOUNT_SUSPENDED',
      message: 'denied',
    ),
  ]) {
    test(
      'authorization loss clears account state and invokes auth: ${error.code}',
      () async {
        final auth = historyAuth(onSessionEnded: () => controller.clear());
        addTearDown(auth.dispose);
        controller.dispose();
        controller = HistoryController(
          historyRepository: repository,
          onAuthFailure: auth.handleHistoryAuthFailure,
        );
        await controller.search('ORDER-A');
        await controller.loadDetail('task-1');
        repository.error = error;
        await controller.load();
        expect(controller.activeReference, isNull);
        expect(controller.items, isEmpty);
        expect(controller.detail, isNull);
        expect(controller.detailProofPhoto, isNull);
        expect(controller.accountScopeGeneration, greaterThan(0));
        expect(auth.status, isNot(AuthStatus.authenticated));
      },
    );
  }

  test('detail access loss also erases the selected list reference', () async {
    await controller.search('ORDER-A');
    repository.detailError = const ApiException(
      statusCode: 403,
      code: 'COURIER_ACCESS_DENIED',
      message: 'denied',
    );
    await controller.loadDetail('task-1');
    expect(controller.activeReference, isNull);
    expect(controller.items, isEmpty);
    expect(controller.detail, isNull);
  });

  for (final oldError in [
    null,
    const ApiContractException('history.data'),
    TokenStorageException('read', StateError('unavailable')),
  ]) {
    test(
      'account clear prevents old completion from contaminating new account: $oldError',
      () async {
        final pending = Completer<DeliveryHistoryPage>();
        repository.handler = (_) => pending.future;
        final old = controller.search('OLD');
        controller.clear();
        repository.handler = (_) async => historyPage('NEW');
        await controller.search('NEW');
        if (oldError == null) {
          pending.complete(historyPage('OLD'));
        } else {
          pending.completeError(oldError);
        }
        await old;
        expect(controller.activeReference, 'NEW');
        expect(controller.items.single.order?.reference, 'NEW');
        expect(controller.status, HistoryLoadStatus.loaded);
      },
    );
  }

  for (final error in [
    const ApiException.network('offline'),
    const ApiException.network(
      'timeout',
      networkFailure: ApiNetworkFailure.timeout,
    ),
    const ApiException(statusCode: 409, code: 'CONFLICT', message: 'conflict'),
    const ApiException(
      statusCode: 422,
      code: 'VALIDATION_FAILED',
      message: 'invalid',
    ),
    const ApiException(
      statusCode: 503,
      code: 'FULFILLMENT_UNAVAILABLE',
      message: 'unavailable',
    ),
    const ApiContractException('history.data'),
  ]) {
    test(
      'recoverable error preserves search context without claiming empty: $error',
      () async {
        repository.error = error;
        await controller.search('ORDER-A');
        expect(controller.activeReference, 'ORDER-A');
        expect(controller.status, isNot(HistoryLoadStatus.empty));
        expect(controller.errorMessage, isNotEmpty);
        repository.error = null;
        await controller.retry();
        expect(repository.references, ['ORDER-A', 'ORDER-A']);
      },
    );
  }

  testWidgets('cooldown guards all reads but permits local clear', (
    tester,
  ) async {
    repository.error = const ApiException(
      statusCode: 429,
      code: 'TOO_MANY_REQUESTS',
      message: 'wait',
      retryAfter: Duration(seconds: 3),
    );
    await controller.search('ORDER-A');
    await controller.search('ORDER-B');
    await controller.load();
    await controller.retry();
    expect(repository.references, ['ORDER-A']);
    expect(controller.activeReference, 'ORDER-A');
    await controller.clearSearch();
    expect(controller.activeReference, isNull);
    expect(controller.status, HistoryLoadStatus.rateLimited);
    expect(repository.references, ['ORDER-A']);
    repository.error = null;
    await tester.pump(const Duration(seconds: 3));
    await controller.retry();
    expect(repository.references, ['ORDER-A', null]);
  });

  test('storage failure erases private search state', () async {
    await controller.search('ORDER-A');
    repository.error = TokenStorageException('read', StateError('unavailable'));
    await controller.load();
    expect(controller.activeReference, isNull);
    expect(controller.items, isEmpty);
    expect(controller.status, HistoryLoadStatus.secureStorageFailure);
  });

  testWidgets(
    'Clear preserves an access denial while a prior cooldown expires',
    (tester) async {
      repository.error = const ApiException(
        statusCode: 429,
        code: 'TOO_MANY_REQUESTS',
        message: 'wait',
        retryAfter: Duration(seconds: 3),
      );
      await controller.search('ORDER-A');
      repository.detailError = const ApiException(
        statusCode: 403,
        code: 'COURIER_ACCESS_DENIED',
        message: 'denied',
      );
      await controller.loadDetail('task-1');
      await controller.clearSearch();
      expect(controller.status, HistoryLoadStatus.forbidden);
      await tester.pump(const Duration(seconds: 3));
      await controller.search('ORDER-B');
      await controller.load();
      expect(repository.references, ['ORDER-A']);
      expect(controller.activeReference, isNull);
    },
  );

  test(
    'disposal ignores pending responses without notifying disposed listeners',
    () async {
      final pending = Completer<DeliveryHistoryPage>();
      repository.handler = (_) => pending.future;
      final search = controller.search('A');
      final disposedController = controller;
      disposedController.dispose();
      controller = HistoryController(
        historyRepository: HistorySearchRepository(),
      );
      pending.complete(historyPage('A'));
      await search;
      expect(disposedController.items, isEmpty);
      expect(disposedController.activeReference, isNull);
    },
  );
}
