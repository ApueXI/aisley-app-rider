// Synthetic browser acceptance for G29. No live API or secure storage access.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

late SemanticsHandle _semantics;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _semantics = SemanticsBinding.instance.ensureSemantics();
  runApp(const _Fixture());
}

class _Fixture extends StatefulWidget {
  const _Fixture();
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  late final DeliveryController delivery;
  late final AuthController auth;
  final attempts = <String, Map<String, Object?>>{};
  final keys = <String>[];
  bool failedOnce = false;
  int postCount = 0;
  int proofCount = 0;
  bool photoExists = false;
  int completionWrites = 0;
  final scenario = Uri.base.queryParameters['scenario'] ?? 'normal';
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  final large = Uri.base.queryParameters['text'] == 'large';
  final task = const PickupTask(
    id: 'task-1',
    leg: PickupTaskLeg.finalMile,
    rawStatus: 'out_for_delivery',
    revision: 7,
    order: PickupOrderReference(reference: 'ORD-SYNTHETIC'),
  );

  @override
  void initState() {
    super.initState();
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _Storage(),
      client: MockClient(_response),
    );
    auth = AuthController(
      authRepository: _AuthRepository(),
      dashboardRepository: _DashboardRepository(),
    );
    auth.status = AuthStatus.authenticated;
    auth.courier = CourierIdentity.fromJson({
      'id': 'courier-1',
      'email': 'courier@example.test',
      'role': 'courier',
      'status': 'active',
      'profile': {'first_name': 'Ana', 'last_name': 'Courier'},
      'logistics': {
        'status': 'approved',
        'organization': 'Demo Logistics',
        'hub': 'Demo Hub',
      },
    });
    delivery = DeliveryController(
      deliveryRepository: ApiDeliveryRepository(client: client),
    )..tasks = [task];
    if (scenario == 'stale_photo') {
      photoExists = true;
      attempts['existing'] = _receipt(
        'existing',
        'recipient_unavailable',
        null,
      );
    }
  }

  Map<String, Object?> _receipt(String id, String reason, String? note) => {
    'id': id,
    'task_id': 'task-1',
    'reason': reason,
    'note': note,
    'attempted_at': '2026-10-11T09:00:00Z',
    'retry_allowed': true,
  };

  Future<http.Response> _response(http.Request request) async {
    final path = request.url.path;
    final data = <String, Object?>{
      'task_id': 'task-1',
      'id': 'task-1',
      'leg': 'final_mile',
      'status': 'out_for_delivery',
      'revision': 7,
      'order': {
        'reference': 'ORD-SYNTHETIC',
        'payment_method': 'cod',
        'payment_status': 'pending',
        'payable_total': '115.00',
        'currency': 'PHP',
      },
      'hub': {'hub_name': 'Demo Hub'},
      'destination': {'city_municipality': 'Pasig', 'province': 'Metro Manila'},
      'failed_attempt_count': attempts.length,
      'failed_attempts': attempts.values.toList().reversed.take(10).toList(),
    };
    if (path.endsWith('/failed-attempts')) {
      postCount++;
      keys.add(request.headers['idempotency-key']!);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final key = keys.last;
      if (scenario == 'key_conflict') {
        return http.Response(
          jsonEncode({
            'code': 'IDEMPOTENCY_KEY_REUSED',
            'message': 'Internal diagnostic',
          }),
          409,
        );
      }
      if (scenario == 'validation' && !failedOnce) {
        failedOnce = true;
        return http.Response(
          jsonEncode({
            'code': 'VALIDATION_FAILED',
            'message': 'Private diagnostic',
            'errors': {
              'note': ['Internal diagnostic'],
            },
          }),
          422,
        );
      }
      if (scenario == 'throttle' && !failedOnce) {
        failedOnce = true;
        return http.Response(
          jsonEncode({'code': 'TOO_MANY_REQUESTS', 'message': 'Throttle'}),
          429,
          headers: {'retry-after': '2'},
        );
      }
      attempts.putIfAbsent(
        key,
        () => _receipt(
          'attempt-${attempts.length + 1}',
          body['reason'] as String,
          body['note'] as String?,
        ),
      );
      if (scenario == 'lost_response' && !failedOnce) {
        failedOnce = true;
        setState(() {});
        throw TimeoutException('Synthetic lost response');
      }
      setState(() {});
      return http.Response(jsonEncode({'data': attempts[key]}), 201);
    }
    if (path.endsWith('/completion')) {
      if (request.method == 'POST') completionWrites++;
      return http.Response(
        jsonEncode({
          'data': {
            'task_id': 'task-1',
            'task_status': 'out_for_delivery',
            'revision': 7,
            'intent_id': scenario == 'pending' ? 'intent-1' : null,
            'completion_status': scenario == 'pending'
                ? 'awaiting_validation'
                : null,
            'evidence_id': photoExists ? 'proof-1' : null,
            'evidence_status': photoExists
                ? 'awaiting_validation'
                : 'unavailable',
            'proof_failed_attempt_count': photoExists ? proofCount : null,
          },
        }),
        200,
      );
    }
    if (path.endsWith('/photo')) {
      return http.Response.bytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9AAAAAElFTkSuQmCC',
        ),
        200,
        headers: {'content-type': 'image/png'},
      );
    }
    return http.Response(jsonEncode({'data': data}), 200);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildCourierTheme(Brightness.light),
    darkTheme: buildCourierTheme(Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
      child: child!,
    ),
    home: Scaffold(
      body: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Fixture: $postCount requests, ${attempts.length} attempts, '
              '${keys.toSet().length} keys, $completionWrites completions',
            ),
          ),
          Expanded(
            child: DeliveryTaskScreen(
              authController: auth,
              deliveryController: delivery,
              task: task,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    delivery.dispose();
    auth.dispose();
    _semantics.dispose();
    super.dispose();
  }
}

class _Storage implements TokenStorage {
  @override
  Future<String?> read() async => 'synthetic-token';
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

class _AuthRepository implements AuthRepository {
  @override
  Future<void> logout() async {}
  @override
  Future<void> clearStoredToken() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DashboardRepository implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
