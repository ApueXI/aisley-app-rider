import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/account/data/account_repository.dart';
import 'package:aisley_app/features/account/domain/account_models.dart';
import 'package:aisley_app/features/account/presentation/controllers/account_controller.dart';
import 'package:aisley_app/features/account/presentation/account_screen.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

import '../auth/fixtures/registration_screen_fixture.dart';

void main() {
  setUp(() {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = TestImagePicker();
    addTearDown(() => FileSelectorPlatform.instance = original);
  });
  testWidgets('renders the server-backed account form and read-only details', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    )..status = AuthStatus.authenticated;
    final accountController = AccountController(
      accountRepository: _FakeAccountRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          authController: authController,
          accountController: accountController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal information'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Aisley Express'), findsOneWidget);
    expect(find.text('Main Hub'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });

  for (final systemBack in [false, true]) {
    testWidgets(
      'account ${systemBack ? 'system' : 'toolbar'} Back protects profile drafts',
      (tester) async {
        await _openAccount(tester);
        await enter(tester, 'First name', 'Edited');
        Future<void> back() async {
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Back'));
          }
          await tester.pumpAndSettle();
        }

        await back();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('First name')).controller!.text,
          'Edited',
        );
        await back();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.text('Account destination'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'unchanged, reverted, and saved account profiles leave without a prompt',
    (tester) async {
      for (final mode in ['unchanged', 'reverted', 'saved']) {
        await _openAccount(tester);
        if (mode != 'unchanged') await enter(tester, 'First name', 'Edited');
        if (mode == 'reverted') await enter(tester, 'First name', 'Ana');
        if (mode == 'saved') {
          await tester.ensureVisible(find.text('Save profile'));
          await tester.tap(find.text('Save profile'));
          await tester.pumpAndSettle();
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Account destination'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      }
    },
  );

  testWidgets(
    'password drafts are protected and successful change clears drafts without a second prompt',
    (tester) async {
      final (auth, account) = await _openAccount(tester);
      await enter(tester, 'First name', 'Edited');
      await enter(tester, 'Current password', 'TestCurrent123');
      await enter(tester, 'New password', 'TestNew123');
      await enter(tester, 'Confirm new password', 'TestNew123');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Change password'));
      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unsaved profile changes'), findsOneWidget);
      await tester.tap(find.text('Change password').last);
      await tester.pumpAndSettle();
      expect(account.status, AccountStatus.signedOut);
      expect(auth.status, AuthStatus.signedOut);
      expect(find.text('Account destination'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('pending photo alone is protected on exit', (tester) async {
    await _openAccount(tester);
    await tester.ensureVisible(find.text('Choose photo'));
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Upload photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'session expiry dismisses an open discard prompt and clears local drafts',
    (tester) async {
      final (auth, _) = await _openAccount(tester);
      await enter(tester, 'First name', 'Edited');
      final draft = tester.widget<TextField>(field('First name')).controller!;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(draft.text, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Account destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account denial clears drafts and exits without discard confirmation',
    (tester) async {
      final repository = _FakeAccountRepository();
      final (_, account) = await _openAccount(tester, repository: repository);
      await enter(tester, 'First name', 'Edited');
      repository.fetchError = const ApiException(
        statusCode: 403,
        code: 'LOGISTICS_ASSOCIATION_INVALID',
        message: 'Denied',
      );
      await account.loadAccount();
      await tester.pumpAndSettle();
      expect(find.text('Account destination'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'validation reveals first account error and preserves recoverable edits',
    (tester) async {
      final repository = _FakeAccountRepository();
      repository.saveError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'Invalid',
        fieldErrors: {
          'contact_number': ['Invalid contact.'],
          'first_name': ['Invalid first name.'],
        },
      );
      await _openAccount(tester, repository: repository);
      await enter(tester, 'First name', 'Edited');
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('First name')).focusNode!.hasFocus,
        true,
      );
      expect(
        tester.widget<TextField>(field('First name')).controller!.text,
        'Edited',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
    },
  );
}

Future<(AuthController, AccountController)> _openAccount(
  WidgetTester tester, {
  _FakeAccountRepository? repository,
}) async {
  final auth = AuthController(
    authRepository: _FakeAuthRepository(),
    dashboardRepository: _FakeDashboardRepository(),
  )..status = AuthStatus.authenticated;
  final account = AccountController(
    accountRepository: repository ?? _FakeAccountRepository(),
    onPasswordChanged: () async {
      await auth.signOut();
    },
  );
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AccountScreen(
                  authController: auth,
                  accountController: account,
                ),
              ),
            ),
            child: const Text('Account destination'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Account destination'));
  await tester.pumpAndSettle();
  return (auth, account);
}

class _FakeAccountRepository implements AccountRepository {
  ApiException? fetchError;
  ApiException? saveError;
  @override
  Future<CourierAccount> fetchAccount() async {
    if (fetchError case final error?) throw error;
    return CourierAccount.fromJson(_accountJson);
  }

  @override
  Future<CourierAccount> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
    String? idempotencyKey,
  }) async {
    if (saveError case final error?) throw error;
    return CourierAccount.fromJson({
      ..._accountJson,
      'profile': {
        ...(_accountJson['profile']! as Map<String, dynamic>),
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'contact_number': contactNumber,
      },
    });
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {}

  @override
  Future<CourierAccount> uploadProfilePhoto({
    required ProfilePhotoSelection selection,
    String? idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    return CourierAccount.fromJson(_accountJson);
  }

  @override
  Future<ProfilePhotoData> fetchProfilePhoto(String profilePhotoUrl) async {
    throw const ApiException(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'missing',
    );
  }

  @override
  Future<void> deleteProfilePhoto() async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<bool> hasStoredToken() async => false;

  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async {
    return const <LogisticsOption>[];
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
    throw UnimplementedError();
  }

  @override
  Future<CourierIdentity> currentCourier() async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {}
}

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    throw UnimplementedError();
  }
}

const _accountJson = <String, dynamic>{
  'id': 'courier-1',
  'email': 'courier@example.com',
  'role': 'courier',
  'status': 'active',
  'profile': <String, dynamic>{
    'first_name': 'Ana',
    'middle_name': null,
    'last_name': 'Santos',
    'contact_number': '09171234567',
    'sex': 'female',
    'birth_date': '1999-01-01',
    'age': 27,
    'profile_photo_url': null,
  },
  'affiliation': <String, dynamic>{
    'status': 'approved',
    'organization_name': 'Aisley Express',
    'hub_name': 'Main Hub',
  },
  'security': <String, dynamic>{
    'email_editable': false,
    'profile_photo_editable': true,
    'password_change_requires_current_password': true,
  },
};
