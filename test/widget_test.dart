import 'package:aisley_app/features/policy/domain/policy_batch_acceptance.dart';

import 'features/auth/fixtures/registration_screen_fixture.dart'
    as registration;

import 'package:aisley_app/features/auth/data/registration_email.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/app/courier_app.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:aisley_app/features/policy/data/policy_repository.dart';
import 'package:aisley_app/features/policy/domain/policy_models.dart';
import 'package:aisley_app/features/policy/presentation/controllers/policy_controller.dart';

void main() {
  testWidgets('registration allows Truck and retains the selected value', (
    WidgetTester tester,
  ) async {
    final fixture = registration.RegistrationScreenFixture();
    await fixture.open(tester);
    await fixture.fill(tester, stopAt: 3);

    final dropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Vehicle type',
    );
    await tester.ensureVisible(dropdown);
    await tester.pump();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Truck').last);
    await tester.pumpAndSettle();

    final selected = tester.widget<DropdownButtonFormField<String>>(dropdown);
    expect(selected.initialValue, 'truck');
    expect(
      find.byKey(const ValueKey<String?>('vehicle-truck')),
      findsOneWidget,
    );
  });

  testWidgets('Courier can open the registration form from sign in', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    );
    await controller.initialize();

    await tester.pumpWidget(CourierApp(authController: controller));
    await tester.tap(find.text('Create account'));
    await _pumpUntilFound(tester, find.text('Create your account'));

    expect(find.text('Step 1 of 6 · Personal details'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Required evidence'), findsNothing);
  });

  testWidgets('registration explains local validation failures at the top', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    );
    await controller.initialize();

    await tester.pumpWidget(CourierApp(authController: controller));
    await tester.tap(find.text('Create account'));
    await _pumpUntilFound(tester, find.text('Create your account'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(
      find.text('Review the highlighted fields before continuing.'),
      findsOneWidget,
    );
    expect(find.text('Enter your first name.'), findsOneWidget);
  });

  testWidgets('Courier can sign in and reach the dashboard skeleton', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    );
    await controller.initialize();

    await tester.pumpWidget(CourierApp(authController: controller));
    expect(find.text('AISLEY Rider'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsLabel('Email'),
      'courier@example.com',
    );
    await tester.enterText(find.bySemanticsLabel('Password'), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('AISLEY Rider'), findsOneWidget);
    expect(find.text('Available work'), findsNothing);
    expect(find.text('Summary unavailable'), findsNothing);
    expect(
      find.text(
        'Work summaries are unavailable. Open a work list for current tasks.',
      ),
      findsOneWidget,
    );
    expect(find.text('Notification summary'), findsNothing);
    await tester.scrollUntilVisible(find.text('Refresh dashboard'), 300);
    expect(find.text('Refresh dashboard'), findsOneWidget);
  });

  testWidgets('dashboard contract failure is not shown as empty work', (
    WidgetTester tester,
  ) async {
    final authController =
        AuthController(
            authRepository: _FakeAuthRepository(),
            dashboardRepository: _FakeDashboardRepository()
              ..error = const ApiContractException('dashboard.sections'),
          )
          ..status = AuthStatus.authenticated
          ..courier = _FakeAuthRepository().courier;

    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(authController: authController)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('summaries could not be loaded'),
      findsOneWidget,
    );
    expect(find.text('Nothing to show'), findsNothing);
    expect(find.text('Summary unavailable'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('dashboard shows identity and affiliation without a photo', (
    WidgetTester tester,
  ) async {
    final authController =
        AuthController(
            authRepository: _FakeAuthRepository(),
            dashboardRepository: _FakeDashboardRepository(),
          )
          ..status = AuthStatus.authenticated
          ..courier = _FakeAuthRepository().courier;

    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(authController: authController)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maya Santos'), findsOneWidget);
    expect(find.text('Aisley Express · Makati Hub'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dashboard-profile-photo')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    authController.dispose();
  });

  testWidgets('policy-gated dashboard opens consent without signing out', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    )..status = AuthStatus.policyConsentRequired;
    final policyController = PolicyController(policyApi: _FakePolicyApi());

    await tester.pumpWidget(
      CourierApp(
        authController: authController,
        policyController: policyController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms & Privacy consent'), findsOneWidget);
    expect(
      find.text('Accept the required policies to continue to your work.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var index = 0; index < 100; index++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

class _FakeAuthRepository
    implements AuthRepository, RegistrationEmailRepository {
  @override
  Future<RegistrationEmailChallenge> requestRegistrationCode(
    String email,
  ) async => RegistrationEmailChallenge(
    id: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    resendAt: DateTime.now(),
  );
  @override
  Future<RegistrationEmailProof> verifyRegistrationEmail(
    String email,
    String challengeId,
    String code,
  ) async => RegistrationEmailProof(
    token: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );

  final CourierIdentity courier = CourierIdentity.fromJson(
    const <String, dynamic>{
      'id': 'courier-1',
      'email': 'courier@example.com',
      'role': 'courier',
      'status': 'active',
      'profile': <String, dynamic>{'first_name': 'Maya', 'last_name': 'Santos'},
      'logistics': <String, dynamic>{
        'status': 'approved',
        'organization': 'Aisley Express',
        'hub': 'Makati Hub',
      },
    },
  );

  @override
  Future<bool> hasStoredToken() async => false;

  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async {
    return const <LogisticsOption>[
      LogisticsOption(id: 'logistics-1', businessName: 'Aisley Express'),
    ];
  }

  @override
  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    return courier;
  }

  @override
  Future<CourierIdentity> currentCourier() async => courier;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {}
}

class _FakeDashboardRepository implements DashboardRepository {
  Object? error;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    if (error case final error?) throw error;
    return DashboardSnapshot.fromScaffoldResponse(const <String, dynamic>{
      'data': <dynamic>[],
      'meta': <String, dynamic>{'next_cursor': null, 'generated_at': 'now'},
      'sections': <String, dynamic>{
        'notifications': <String, dynamic>{
          'state': 'unavailable',
          'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
        },
        'available_tasks': <String, dynamic>{
          'state': 'unavailable',
          'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
        },
        'active_tasks': <String, dynamic>{
          'state': 'unavailable',
          'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
        },
      },
      'freshness': <String, dynamic>{
        'state': 'scaffold',
        'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
        'generated_at': 'now',
      },
    });
  }
}

class _FakePolicyApi implements PolicyApi {
  @override
  Future<PolicyDocument> fetchCurrent(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    return _policyDocument(type);
  }

  @override
  Future<PolicyHistory> fetchHistory(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    return PolicyHistory(
      type: type,
      label: type.fallbackLabel,
      versions: const <PolicyHistoryEntry>[],
    );
  }

  @override
  Future<PolicyDocument> fetchHistoryVersion(
    PolicyType type,
    int version, {
    bool forceRefresh = false,
  }) async {
    return _policyDocument(type);
  }

  @override
  Future<PolicyConsentStatus> fetchConsentStatus() async {
    return const PolicyConsentStatus(
      policies: <PolicyConsentItem>[
        PolicyConsentItem(
          rawType: 'terms_of_service',
          label: 'Terms of Service',
          required: true,
          accepted: false,
          acceptedAt: null,
          currentVersion: 1,
          acceptedVersion: null,
        ),
        PolicyConsentItem(
          rawType: 'privacy_policy',
          label: 'Privacy Policy',
          required: true,
          accepted: false,
          acceptedAt: null,
          currentVersion: 1,
          acceptedVersion: null,
        ),
      ],
      allRequiredAccepted: false,
    );
  }

  @override
  Future<PolicyAcceptance> accept({
    required PolicyType type,
    required int version,
  }) async {
    return PolicyAcceptance(
      type: type,
      label: type.fallbackLabel,
      version: _policyDocument(type).version,
      acceptedAt: DateTime.utc(2026, 9, 12),
    );
  }

  @override
  Future<PolicyBatchAcceptance> acceptTogether(
    Map<PolicyType, int> versions,
  ) async {
    throw UnimplementedError(
      'Batch acceptance must be configured by the test.',
    );
  }

  @override
  void clearPublicCache() {}
}

PolicyDocument _policyDocument(PolicyType type) {
  return PolicyDocument(
    type: type,
    label: type.fallbackLabel,
    version: PolicyVersion(
      id: '${type.apiValue}-1',
      version: 1,
      title: type.fallbackLabel,
      content: 'Policy content.',
      status: 'published',
      changeSummary: null,
      requiresReconsent: false,
      publishedAt: DateTime.utc(2026, 9, 12),
    ),
  );
}
