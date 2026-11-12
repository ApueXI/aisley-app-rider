import 'dart:io';
import 'dart:ui' as ui;

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/app/appearance/appearance_controller.dart';
import 'package:aisley_app/app/appearance/appearance_scope.dart';
import 'package:aisley_app/features/account/presentation/controllers/account_controller.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/history/presentation/controllers/history_controller.dart';
import 'package:aisley_app/features/linehaul/presentation/linehaul_controller.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:aisley_app/features/policy/data/policy_repository.dart';
import 'package:aisley_app/features/policy/presentation/controllers/policy_controller.dart';
import 'package:aisley_app/features/support/presentation/controllers/support_ticket_controller.dart';
import 'package:aisley_app/features/vehicle/data/vehicle_repository.dart';
import 'package:aisley_app/features/vehicle/presentation/controllers/vehicle_controller.dart';
import 'package:aisley_app/shared/presentation/courier_viewport.dart';
import 'package:aisley_app/shared/presentation/destination_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/account/fixtures/account_screen_fixture.dart';
import '../features/auth/fixtures/registration_screen_fixture.dart';
import '../features/batch/fixtures/final_mile_batch_screen_fixture.dart';
import '../features/history/fixtures/history_search_fixture.dart';
import '../features/linehaul/linehaul_fixture.dart';
import '../features/notification/fixtures/navigation_fixture.dart';
import '../features/support/fixtures/support_ticket_screen_fixture.dart';

const _captureEnabled = bool.fromEnvironment(
  'CAPTURE_STITCH_SHELL',
  defaultValue: false,
);
const _fontDirectory = String.fromEnvironment('FLUTTER_FONT_DIR');
const _captureDirectory = String.fromEnvironment(
  'STITCH_CAPTURE_DIRECTORY',
  defaultValue: 'build/stitch-ui/shell',
);

void main() {
  if (!_captureEnabled) return;

  setUpAll(() async {
    if (_fontDirectory.isEmpty) {
      throw StateError(
        'Set FLUTTER_FONT_DIR to the local Flutter font folder.',
      );
    }
    final body = FontLoader('Roboto');
    for (final file in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      body.addFont(
        File('$_fontDirectory/$file')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await body.load();
    await (FontLoader('MaterialIcons')..addFont(
          File('$_fontDirectory/MaterialIcons-Regular.otf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
  });

  testWidgets('captures synthetic Home, Work and Account Stitch screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1768);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pickupRepository = NavigationPickupRepository();
    final deliveryRepository = NavigationDeliveryRepository();
    final pickup = PickupController(pickupRepository: pickupRepository);
    final delivery = DeliveryController(deliveryRepository: deliveryRepository);
    final dashboard =
        AuthController(
            authRepository: RegistrationTestRepository(),
            dashboardRepository: _SyntheticDashboard(),
          )
          ..status = AuthStatus.authenticated
          ..courier = const CourierIdentity(
            id: 'synthetic-courier-2048',
            email: 'mika@example.invalid',
            role: 'courier',
            status: CourierAccountStatus.active,
            profile: CourierProfile(firstName: 'Mika', lastName: 'Santos'),
            logistics: LogisticsAffiliation(
              status: CourierAffiliationStatus.approved,
              organizationName: 'Example Logistics',
              hubName: 'Main hub',
            ),
          );
    final account = AccountController(
      accountRepository: FakeAccountRepository(),
    );
    final appearance = AppearanceController(
      store: _ScreenshotAppearanceStore(),
      defaultMode: ThemeMode.system,
    );
    final batch = FinalMileBatchController(repository: WidgetBatchRepository());
    final history = HistoryController(
      historyRepository: HistorySearchRepository(),
    );
    final linehaul = LinehaulController(FakeLinehaulRepository());
    final notifications = NotificationController(
      notificationRepository: NavigationNotificationRepository(),
    );
    final support = SupportTicketController(
      repository: WidgetSupportRepository(),
    );
    final policy = PolicyController(policyApi: _ScreenshotPolicyApi());
    final vehicle = VehicleController(
      vehicleRepository: _ScreenshotVehicleRepository(),
    );

    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCourierTheme(Brightness.light),
        navigatorObservers: [courierRouteObserver],
        builder: (context, child) => CourierViewport(
          child: RepaintBoundary(key: boundary, child: child!),
        ),
        home: AppearanceRoot(
          controller: appearance,
          child: DashboardScreen(
            authController: dashboard,
            accountController: account,
            batchController: batch,
            linehaulController: linehaul,
            policyController: policy,
            pickupController: pickup,
            deliveryController: delivery,
            historyController: history,
            notificationController: notifications,
            supportTicketController: support,
            vehicleController: vehicle,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(NavigationBar)).height, 64);
    await _capture(tester, boundary, 'home');

    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await _capture(tester, boundary, 'work');

    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await _capture(tester, boundary, 'account');

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    pickup.dispose();
    delivery.dispose();
    account.dispose();
    batch.dispose();
    history.dispose();
    linehaul.dispose();
    notifications.dispose();
    support.dispose();
    policy.dispose();
    vehicle.dispose();
    dashboard.dispose();
  });
}

class _ScreenshotAppearanceStore implements AppearanceStore {
  @override
  Future<String?> read() async => 'system';

  @override
  Future<void> write(String value) async {}
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory(_captureDirectory);
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    image.dispose();
  });
}

class _SyntheticDashboard implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async => const DashboardSnapshot(
    freshness: DashboardFreshness(
      state: DashboardFreshnessState.partial,
      generatedAt: '2026-10-28T01:41:00Z',
    ),
    sections: {
      'active_tasks': DashboardSection(
        state: DashboardSectionState.available,
        generatedAt: '2026-10-28T01:41:00Z',
        items: [
          {
            'leg': 'final_mile',
            'status': 'delivery_accepted',
            'order_reference': 'ORD-DEMO-1042',
          },
        ],
      ),
      'available_tasks': DashboardSection(
        state: DashboardSectionState.stale,
        generatedAt: '2026-10-28T01:41:00Z',
        items: [
          {
            'leg': 'first_mile',
            'status': 'assigned',
            'order_reference': 'ORD-DEMO-1043',
          },
        ],
      ),
      'notifications': DashboardSection(state: DashboardSectionState.empty),
    },
  );
}

class _ScreenshotPolicyApi implements PolicyApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _ScreenshotVehicleRepository implements VehicleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
