import 'package:aisley_app/features/auth/data/registration_email.dart';

import '../../../helpers/accessibility.dart';

import 'package:aisley_app/app/courier_theme.dart';

import 'dart:async';
import 'dart:convert';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/auth/presentation/registration_screen.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
// The existing picker dependency exposes its test platform through this package.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class RegistrationScreenFixture {
  final repository = RegistrationTestRepository();
  DateTime Function()? verificationClock;
  late final auth = AuthController(
    authRepository: repository,
    dashboardRepository: _UnusedDashboardRepository(),
  );

  Future<void> open(
    WidgetTester tester, {
    double textScale = 1,
    AccessibilityScenario? scenario,
    bool settle = true,
    bool verifyEmail = true,
  }) async {
    const regionIndex = 'lib/psgc-address-data/data/list-of-all-regions.json';
    rootBundle.clear();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (name == regionIndex) {
        return ByteData.sublistView(
          Uint8List.fromList(
            utf8.encode(
              jsonEncode([
                {
                  'psgc_code': 'test-region',
                  'name': 'Test Region',
                  'file': 'test-region.json',
                },
              ]),
            ),
          ),
        );
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMessageHandler('flutter/assets', null);
      rootBundle.clear();
    });
    var editing = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCourierTheme(Brightness.light),
        darkTheme: buildCourierTheme(Brightness.dark),
        themeMode: scenario?.brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scenario?.scale ?? textScale),
          ),
          child: child!,
        ),
        home: StatefulBuilder(
          builder: (context, update) => editing
              ? RegistrationScreen(
                  authController: auth,
                  verificationClock: verificationClock,
                  onSignIn: () => update(() => editing = false),
                )
              : const Scaffold(body: Text('Sign in destination')),
        ),
      ),
    );
    await tester.pump();
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> fill(
    WidgetTester tester, {
    bool evidence = true,
    bool manualAddress = true,
    int stopAt = 5,
  }) async {
    await fillPersonal(tester);
    await nextRegistrationStep(tester);
    await enter(tester, 'Street / house detail', 'Test street');
    await enter(tester, 'Postal code', '0123');
    if (!manualAddress) return;
    await tester.ensureVisible(find.text('Use manual address entry instead'));
    await tester.tap(find.text('Use manual address entry instead'));
    await tester.pumpAndSettle();
    for (final label in [
      'Region',
      'Province',
      'City / municipality',
      'Barangay',
    ]) {
      await enter(tester, label, 'Test $label');
    }
    await nextRegistrationStep(tester, settle: stopAt != 3);
    if (stopAt == 3) return;
    await select(tester, 'Logistics organization', 'Test Logistics');
    await select(tester, 'Vehicle type', 'Truck');
    await enter(tester, 'Plate number', 'TEST-123');
    await nextRegistrationStep(tester);
    if (!evidence) return;
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Choose').first);
      await tester.tap(find.text('Choose').first);
      await tester.pumpAndSettle();
    }
    await nextRegistrationStep(tester);
    await enter(tester, 'Password', 'TestInput123');
    await enter(tester, 'Confirm password', 'TestInput123');
  }

  Future<void> fillPersonal(WidgetTester tester) async {
    await enter(tester, 'Email', 'courier@example.com');
    await enter(tester, 'First name', 'Ana');
    await enter(tester, 'Last name', 'Santos');
    await enter(tester, 'Contact number', '09171234567');
    await select(tester, 'Sex', 'Female');
    await tester.ensureVisible(field('Birth date'));
    await tester.tap(field('Birth date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    while (registrationStep(tester) < 5) {
      final before = registrationStep(tester);
      await nextRegistrationStep(tester);
      if (registrationStep(tester) == before) return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    if (find.text('Continue to email verification').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('Continue to email verification'));
      await tester.tap(find.text('Continue to email verification'));
      await tester.pumpAndSettle();
    }
    if (find.text('Send verification code').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('Send verification code'));
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await enter(tester, 'Verification code', '012345');
      await tester.ensureVisible(find.text('Verify email'));
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
    }
    final submit = find.widgetWithText(FilledButton, 'Submit registration');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
  skipOffstage: false,
);

Future<void> enter(WidgetTester tester, String label, String text) async {
  final step = switch (label) {
    'Email address' || 'Verification code' => 0,
    'Password' || 'Confirm password' => 5,
    'Street / house detail' ||
    'Address line 2 (optional)' ||
    'Region' ||
    'Province' ||
    'City / municipality' ||
    'Barangay' ||
    'Postal code' => 2,
    'Plate number' => 3,
    _ => 1,
  };
  if (find.byType(RegistrationScreen).evaluate().isNotEmpty) {
    await navigateRegistrationStep(tester, step);
  }
  await reveal(tester, field(label));
  await tester.enterText(field(label), text);
  await tester.pump();
}

Future<void> select(WidgetTester tester, String label, String choice) async {
  await navigateRegistrationStep(tester, label == 'Sex' ? 1 : 3);
  final dropdown = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField &&
        widget.decoration.labelText == label,
  );
  await tester.ensureVisible(dropdown);
  await tester.pump();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice).last);
  await tester.pumpAndSettle();
}

int registrationStep(WidgetTester tester) {
  final progress = tester
      .widgetList<Text>(find.byType(Text))
      .firstWhere((text) => text.data?.startsWith('Step ') == true);
  final displayed = int.parse(progress.data!.split(' ')[1]);
  return displayed == 6 ? 0 : displayed;
}

Future<void> nextRegistrationStep(
  WidgetTester tester, {
  bool settle = true,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
  final next = find.widgetWithText(
    FilledButton,
    registrationStep(tester) == 5
        ? 'Continue to email verification'
        : 'Continue',
  );
  await tester.ensureVisible(next);
  await tester.pump();
  await tester.tap(next);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> navigateRegistrationStep(WidgetTester tester, int target) async {
  for (var attempts = 0; attempts < 8; attempts++) {
    final current = registrationStep(tester);
    if (current == target) return;
    if (current == 0 || (target != 0 && current > target)) {
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    } else {
      await nextRegistrationStep(tester);
      if (registrationStep(tester) == current) return;
    }
  }
}

class TestImagePicker extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile.fromData(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9AAAAAElFTkSuQmCC',
    ),
    name: 'test-image.png',
    path: 'test-image.png',
    mimeType: 'image/png',
  );
}

class RegistrationTestRepository
    implements AuthRepository, RegistrationEmailRepository {
  DateTime Function() clock = DateTime.now;
  @override
  Future<RegistrationEmailChallenge> requestRegistrationCode(
    String email,
  ) async => RegistrationEmailChallenge(
    id: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
    expiresAt: clock().add(const Duration(minutes: 10)),
    resendAt: clock(),
  );
  @override
  Future<RegistrationEmailProof> verifyRegistrationEmail(
    String email,
    String challengeId,
    String code,
  ) async => RegistrationEmailProof(
    token: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    expiresAt: clock().add(const Duration(hours: 1)),
  );

  ApiException? error;
  ApiException? optionsError;
  Completer<List<LogisticsOption>>? pendingOptions;
  Completer<RegistrationResult>? pending;
  bool cancelled = false;
  int submissions = 0;
  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async {
    if (pendingOptions case final pending?) return pending.future;
    if (optionsError case final error?) throw error;
    return const [
      LogisticsOption(id: 'organization-1', businessName: 'Test Logistics'),
    ];
  }

  @override
  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function())? onCancel,
  }) async {
    submissions++;
    onCancel?.call(() => cancelled = true);
    if (error case final error?) throw error;
    if (pending case final pending?) return pending.future;
    return const RegistrationResult(
      message: 'Submitted for approval.',
      courier: CourierIdentity(
        id: 'courier-1',
        email: 'courier@example.com',
        role: 'courier',
        status: CourierAccountStatus.pending,
      ),
    );
  }

  @override
  Future<bool> hasStoredToken() async => false;
  @override
  Future<void> clearStoredToken() async {}
  @override
  Future<void> logout() async {}
  @override
  Future<CourierIdentity> currentCourier() async => throw UnimplementedError();
  @override
  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  }) async => throw UnimplementedError();
}

class _UnusedDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async =>
      throw UnimplementedError();
}
