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
  late final auth = AuthController(
    authRepository: repository,
    dashboardRepository: _UnusedDashboardRepository(),
  );

  Future<void> open(WidgetTester tester, {double textScale = 1}) async {
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: StatefulBuilder(
          builder: (context, update) => editing
              ? RegistrationScreen(
                  authController: auth,
                  onSignIn: () => update(() => editing = false),
                )
              : const Scaffold(body: Text('Sign in destination')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    bool evidence = true,
    bool manualAddress = true,
  }) async {
    for (final entry in const {
      'First name': 'Ana',
      'Last name': 'Santos',
      'Contact number': '09171234567',
      'Email': 'courier@example.com',
      'Password': 'TestInput123',
      'Confirm password': 'TestInput123',
      'Street / house detail': 'Test street',
      'Postal code': '0123',
      'Plate number': 'TEST-123',
    }.entries) {
      await enter(tester, entry.key, entry.value);
    }
    await select(tester, 'Sex', 'Female');
    await select(tester, 'Logistics organization', 'Test Logistics');
    await select(tester, 'Vehicle type', 'Truck');
    await tester.ensureVisible(field('Birth date'));
    await tester.tap(field('Birth date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    if (manualAddress) {
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
    }
    if (evidence) {
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('Choose').first);
        await tester.tap(find.text('Choose').first);
        await tester.pumpAndSettle();
      }
    }
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Submit registration'));
    await tester.tap(find.text('Submit registration'));
    await tester.pumpAndSettle();
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> enter(WidgetTester tester, String label, String text) async {
  if (field(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field(label),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), text);
  await tester.pump();
}

Future<void> select(WidgetTester tester, String label, String choice) async {
  final dropdown = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField &&
        widget.decoration.labelText == label,
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice).last);
  await tester.pumpAndSettle();
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

class RegistrationTestRepository implements AuthRepository {
  ApiException? error;
  Completer<RegistrationResult>? pending;
  bool cancelled = false;
  int submissions = 0;
  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async =>
      const [
        LogisticsOption(id: 'organization-1', businessName: 'Test Logistics'),
      ];
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
