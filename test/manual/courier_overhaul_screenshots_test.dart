import 'package:flutter/services.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/auth/presentation/login_screen.dart';
import 'package:aisley_app/features/auth/presentation/registration_screen.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
// The existing picker dependency exposes its test platform through this package.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import '../features/auth/fixtures/registration_screen_fixture.dart';
import '../features/notification/fixtures/navigation_fixture.dart'
    as navigation;
import '../features/delivery/fixtures/delivery_screen_fixture.dart';

void main() {
  const phase = String.fromEnvironment('SNAPSHOT_PHASE');
  if (phase != 'after') return;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = TestImagePicker();
    addTearDown(() => FileSelectorPlatform.instance = original);
  });
  const fonts = String.fromEnvironment('FLUTTER_FONT_DIR');
  setUpAll(() async {
    if (fonts.isEmpty) {
      throw StateError(
        'FLUTTER_FONT_DIR is required for readable screenshots.',
      );
    }
    final body = FontLoader('Roboto');
    for (final file in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      body.addFont(
        File('$fonts/$file')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await body.load();
    await (FontLoader('MaterialIcons')..addFont(
          File('$fonts/MaterialIcons-Regular.otf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
  });
  for (final brightness in Brightness.values) {
    for (final screen in [
      'home',
      'sign-in',
      'registration-email',
      'registration-review',
    ]) {
      testWidgets('$phase $screen ${brightness.name} synthetic screenshot', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        rootBundle.clear();
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMessageHandler('flutter/assets', (message) async {
          final name = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          if (name == 'lib/psgc-address-data/data/list-of-all-regions.json') {
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
        final pickup = PickupController(
          pickupRepository: navigation.NavigationPickupRepository(),
        );
        final delivery = DeliveryController(
          deliveryRepository: WidgetDeliveryRepository(),
        );
        final notifications = NotificationController(
          notificationRepository: navigation.NavigationNotificationRepository(),
        );
        final auth = AuthController(
          authRepository: RegistrationTestRepository(),
          dashboardRepository: _SyntheticDashboard(),
        );
        if (screen == 'home') {
          auth.status = AuthStatus.authenticated;
          auth.courier = const CourierIdentity(
            id: 'synthetic-courier',
            email: 'courier@example.com',
            role: 'courier',
            status: CourierAccountStatus.active,
            profile: CourierProfile(firstName: 'Maya', lastName: 'Santos'),
            logistics: LogisticsAffiliation(
              status: CourierAffiliationStatus.approved,
              organizationName: 'AISLEY Express',
              hubName: 'Makati Hub',
            ),
          );
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCourierTheme(brightness),
            home: RepaintBoundary(
              key: boundary,
              child: screen == 'home'
                  ? DashboardScreen(
                      authController: auth,
                      pickupController: pickup,
                      deliveryController: delivery,
                      notificationController: notifications,
                    )
                  : screen == 'sign-in'
                  ? LoginScreen(authController: auth, onRegister: () {})
                  : RegistrationScreen(authController: auth, onSignIn: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (screen == 'registration-review') {
          await enter(tester, 'Email address', 'courier@example.com');
          await tester.ensureVisible(find.text('Send verification code'));
          await tester.tap(find.text('Send verification code'));
          await tester.pumpAndSettle();
          await enter(tester, 'Verification code', '012345');
          await tester.ensureVisible(find.text('Verify email'));
          await tester.tap(find.text('Verify email'));
          await tester.pumpAndSettle();
          await RegistrationScreenFixture().fill(tester);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Review your application'));
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final snapshot = await render.toImage();
          final bytes = await snapshot.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final folder = Directory(
            'docs/reports/courier-ui-overhaul/screenshots',
          );
          await folder.create(recursive: true);
          await File('${folder.path}/$phase-$screen-${brightness.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          snapshot.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
        pickup.dispose();
        delivery.dispose();
        notifications.dispose();
        auth.dispose();
      });
    }
  }
}

class _SyntheticDashboard implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async =>
      DashboardSnapshot.fromJson(
        jsonDecode(
          File('docs/features/courier/dashboard/aggregate-example.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>,
      );
}
