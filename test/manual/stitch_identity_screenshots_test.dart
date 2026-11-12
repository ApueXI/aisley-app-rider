import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/auth/presentation/login_screen.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:aisley_app/features/history/domain/history_models.dart';
import 'package:aisley_app/features/history/presentation/controllers/history_controller.dart';
import 'package:aisley_app/features/history/presentation/history_screen.dart';
import 'package:aisley_app/features/notification/data/notification_repository.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:aisley_app/features/notification/presentation/notification_screen.dart';
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/fixtures/registration_screen_fixture.dart';
import '../features/auth/fixtures/registration_screen_fixture.dart'
    as registration;
import '../features/history/fixtures/history_search_fixture.dart' as history;

const _captureEnabled = bool.fromEnvironment(
  'CAPTURE_STITCH_IDENTITY',
  defaultValue: false,
);
const _sdkFonts = String.fromEnvironment(
  'FLUTTER_FONT_DIR',
  defaultValue: '/home/cred/develop/flutter/bin/cache/artifacts/material_fonts',
);
const _captureDirectory = String.fromEnvironment(
  'STITCH_CAPTURE_DIRECTORY',
  defaultValue: 'build/stitch-ui/identity',
);

void main() {
  if (!_captureEnabled) return;

  setUpAll(() async {
    final body = FontLoader('Roboto');
    for (final file in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      body.addFont(
        File('$_sdkFonts/$file')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await body.load();
    await (FontLoader('MaterialIcons')..addFont(
          File('$_sdkFonts/MaterialIcons-Regular.otf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
  });

  for (final screen in [
    'sign-in',
    'registration-otp',
    'messages',
    'history',
    'notifications',
  ]) {
    testWidgets('captures $screen', (tester) async {
      _setViewport(tester);
      final boundary = GlobalKey();
      if (screen == 'sign-in') {
        final authFixture = RegistrationScreenFixture();
        await _pumpCaptureApp(
          tester,
          boundary,
          LoginScreen(authController: authFixture.auth, onRegister: () {}),
        );
        expect(find.text('Sign in to your rider account'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.byTooltip('Show password'), findsOneWidget);
        expect(find.text('Create account'), findsOneWidget);
        expect(find.text('Forgot password'), findsNothing);
        await _capture(tester, boundary, screen);
        await tester.pumpWidget(const SizedBox.shrink());
        authFixture.auth.dispose();
      } else if (screen == 'registration-otp') {
        await _captureRegistrationOtp(tester, boundary);
      } else if (screen == 'messages') {
        final authFixture = RegistrationScreenFixture(
          dashboardRepository: _ScreenshotDashboardRepository(),
        );
        final auth = _activate(authFixture.auth);
        final chat = ChatController(repository: _ScreenshotChatRepository());
        await _pumpCaptureApp(
          tester,
          boundary,
          DashboardScreen(authController: auth, chatController: chat),
        );
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        expect(find.text('Logistics team'), findsOneWidget);
        expect(find.text('ORD-DEMO-2048'), findsOneWidget);
        expect(find.text('1 unread'), findsOneWidget);
        expect(find.text('Example shop'), findsOneWidget);
        expect(find.text('ORD-DEMO-2049'), findsOneWidget);
        expect(find.text('ETA'), findsNothing);
        expect(find.textContaining('online'), findsNothing);
        expect(find.textContaining('directory'), findsNothing);
        await _capture(tester, boundary, screen);
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        auth.dispose();
      } else if (screen == 'history') {
        final repository = history.HistorySearchRepository()
          ..page = DeliveryHistoryPage(items: [_demoHistoryItem]);
        final controller = HistoryController(historyRepository: repository);
        await controller.search('ORD-DEMO-2048');
        final auth = history.historyAuth();
        await _pumpPushedCaptureApp(
          tester,
          boundary,
          HistoryScreen(authController: auth, historyController: controller),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(find.text('Exact Order reference'), findsOneWidget);
        expect(find.text('ORD-DEMO-2048'), findsNWidgets(2));
        expect(find.text('Read-only view'), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
        expect(find.text('Clear'), findsOneWidget);
        await _capture(tester, boundary, screen);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        auth.dispose();
      } else if (screen == 'notifications') {
        final repository = _ScreenshotNotificationRepository();
        final controller = NotificationController(
          notificationRepository: repository,
        );
        await _pumpPushedCaptureApp(
          tester,
          boundary,
          NotificationScreen(controller: controller, managePolling: false),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(find.text('Pickup schedule updated'), findsOneWidget);
        expect(find.text('Support ticket reply'), findsOneWidget);
        expect(find.text('Linehaul trip scheduled'), findsOneWidget);
        expect(find.text('Unread'), findsNWidgets(2));
        expect(find.text('Read'), findsNWidgets(2));
        expect(find.text('Mark all as read'), findsNothing);
        expect(find.text('Open related work'), findsNothing);
        await _capture(tester, boundary, screen);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpCaptureApp(
  WidgetTester tester,
  GlobalKey boundary,
  Widget screen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCourierTheme(Brightness.light),
      home: RepaintBoundary(key: boundary, child: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPushedCaptureApp(
  WidgetTester tester,
  GlobalKey boundary,
  Widget screen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCourierTheme(Brightness.light),
      home: _CaptureRouteLauncher(boundary: boundary, screen: screen),
    ),
  );
  await tester.pumpAndSettle();
}

class _CaptureRouteLauncher extends StatefulWidget {
  const _CaptureRouteLauncher({required this.boundary, required this.screen});

  final GlobalKey boundary;
  final Widget screen;

  @override
  State<_CaptureRouteLauncher> createState() => _CaptureRouteLauncherState();
}

class _CaptureRouteLauncherState extends State<_CaptureRouteLauncher> {
  bool _pushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pushed) return;
    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RepaintBoundary(key: widget.boundary, child: widget.screen),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> _captureRegistrationOtp(
  WidgetTester tester,
  GlobalKey boundary,
) async {
  const regionAsset = 'lib/psgc-address-data/data/list-of-all-regions.json';
  rootBundle.clear();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final name = utf8.decode(
      message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
    );
    if (name != regionAsset) return null;
    return ByteData.sublistView(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode([
            {
              'psgc_code': 'demo-region',
              'name': 'Demo Region',
              'file': 'demo-region.json',
            },
          ]),
        ),
      ),
    );
  });
  addTearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    rootBundle.clear();
  });

  final originalPicker = FileSelectorPlatform.instance;
  FileSelectorPlatform.instance = registration.TestImagePicker();
  addTearDown(() => FileSelectorPlatform.instance = originalPicker);

  final fixture = RegistrationScreenFixture();
  await fixture.open(tester, boundary: boundary);
  await fixture.fill(tester);
  await registration.navigateRegistrationStep(tester, 1);
  await registration.enter(tester, 'Email', 'mika@example.invalid');
  await registration.enter(tester, 'First name', 'Mika');
  await registration.navigateRegistrationStep(tester, 5);
  fixture.repository.resendDelay = const Duration(seconds: 45);
  await registration.nextRegistrationStep(tester);
  await tester.pumpAndSettle();
  expect(find.text('Verify your email'), findsOneWidget);
  expect(find.text('mika@example.invalid'), findsOneWidget);
  expect(find.text('Verification code'), findsOneWidget);
  expect(find.byType(TextField), findsOneWidget);
  expect(find.text('Verify and submit'), findsOneWidget);
  expect(find.textContaining('Resend code ('), findsOneWidget);
  expect(find.text('Back to review'), findsOneWidget);
  expect(find.textContaining('Step '), findsNothing);
  await _capture(tester, boundary, 'registration-otp');
  await tester.pumpWidget(const SizedBox.shrink());
  fixture.auth.dispose();
}

AuthController _activate(AuthController auth) {
  auth
    ..status = AuthStatus.authenticated
    ..courier = const CourierIdentity(
      id: 'synthetic-courier',
      email: 'courier@example.test',
      role: 'courier',
      status: CourierAccountStatus.active,
    );
  return auth;
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
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory(_captureDirectory);
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    image.dispose();
  });
}

final _demoThread = ChatThread(
  id: 'conversation-demo-2048',
  kind: 'logistics_courier',
  leg: 'first_mile',
  taskId: 'task-demo-2048',
  taskReference: 'ORD-DEMO-2048',
  counterpartyRole: 'logistics',
  counterpartyLabel: 'Logistics team',
  unreadCount: 1,
  lastSequence: 2,
  lastReadSequence: 1,
  sendAllowed: true,
  lastMessagePreview: 'Please confirm when you arrive at the hub.',
  lastMessageAt: DateTime.utc(2026, 9, 20, 1, 38),
);

final _demoSellerThread = ChatThread(
  id: 'conversation-demo-2049',
  kind: 'courier_seller',
  leg: 'first_mile',
  taskId: 'task-demo-2049',
  taskReference: 'ORD-DEMO-2049',
  counterpartyRole: 'seller',
  counterpartyLabel: 'Example shop',
  unreadCount: 0,
  lastSequence: 1,
  lastReadSequence: 1,
  sendAllowed: true,
  lastMessagePreview: 'Please confirm the pickup window for this task.',
  lastMessageAt: DateTime.utc(2026, 9, 20, 1, 15),
);

final _demoHistoryItem = DeliveryHistoryItem.fromJson({
  'task_id': 'task-demo-2048',
  'leg': 'final_mile',
  'status': 'delivered',
  'delivered_at': '2026-09-11T08:00:00Z',
  'order': {
    'id': 'order-demo-2048',
    'reference': 'ORD-DEMO-2048',
    'status': 'delivered',
  },
  'pickup_area': {'city_municipality': 'Makati City', 'region': 'NCR'},
  'destination_area': {'city_municipality': 'Pasig City', 'region': 'NCR'},
  'parcel': {
    'id': 'parcel-demo-2048',
    'reference': 'PARCEL-DEMO-2048',
    'item_count': 2,
  },
  'evidence_status': 'validated',
  'completion_status': 'validated',
  'evidence_id': 'evidence-demo-2048',
});

final _demoNotifications = <CourierNotification>[
  CourierNotification(
    id: 'notification-pickup-demo',
    type: 'pickup-schedule.revised',
    title: 'Pickup schedule updated',
    summary: 'A schedule update is available for ORD-DEMO-2047.',
    createdAt: DateTime.utc(2026, 11, 12, 2, 5),
    resourceType: 'pickup_schedule',
    resourceId: 'schedule-demo-2047',
    destination: '/pickup-schedules/schedule-demo-2047',
    category: 'pickups',
    categoryLabel: 'Pickups',
  ),
  CourierNotification(
    id: 'notification-support-demo',
    type: 'support-ticket.admin-replied',
    title: 'Support ticket reply',
    summary: 'An administrator replied to your support ticket.',
    createdAt: DateTime.utc(2026, 11, 12, 1, 20),
    resourceType: 'support_ticket',
    resourceId: '00000000-0000-4000-8000-000000000042',
    destination: '/support-tickets/00000000-0000-4000-8000-000000000042',
    category: 'support',
    categoryLabel: 'Support tickets',
  ),
  CourierNotification(
    id: 'notification-linehaul-demo',
    type: 'courier-linehaul.trip-scheduled',
    title: 'Linehaul trip scheduled',
    summary: 'Your assigned trip was scheduled.',
    createdAt: DateTime.utc(2026, 11, 11, 8, 30),
    readAt: DateTime.utc(2026, 11, 11, 8, 40),
    resourceType: 'linehaul_trip',
    resourceId: 'trip-demo-2046',
    destination: '/linehaul-trips/trip-demo-2046',
    category: 'linehaul',
    categoryLabel: 'Linehaul',
  ),
];

class _ScreenshotChatRepository implements ChatRepository {
  @override
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  }) async => ChatPage<ChatThread>(
    items: [_demoThread, _demoSellerThread],
    nextCursor: null,
    unreadCount: 1,
  );

  @override
  Future<ChatThread> detail(String id) async => _demoThread;

  @override
  Future<ChatPage<ChatMessage>> messages(
    String id, {
    String? cursor,
    int limit = 20,
  }) async => ChatPage<ChatMessage>(
    items: [
      ChatMessage(
        id: 'message-demo-1',
        conversationId: 'conversation-demo-2048',
        sequence: 1,
        senderRole: 'logistics',
        mine: false,
        body: 'Please confirm when you arrive at the hub.',
        createdAt: DateTime.utc(2026, 9, 20, 1, 50),
      ),
    ],
    nextCursor: null,
  );

  @override
  Future<ChatSendResult> start({
    required String leg,
    required String taskId,
    required String counterpartyRole,
    required String body,
    required String idempotencyKey,
    List<String> attachmentIds = const [],
  }) async => throw UnimplementedError();

  @override
  Future<ChatSendResult> send({
    required String id,
    required String body,
    required String idempotencyKey,
    List<String> attachmentIds = const [],
  }) async => throw UnimplementedError();

  @override
  Future<ChatThread> markRead(String id, int lastReadSequence) async =>
      _demoThread;
}

class _ScreenshotDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async => DashboardSnapshot(
    sections: const {},
    freshness: const DashboardFreshness(
      state: DashboardFreshnessState.scaffold,
      reason: 'OPERATIONAL_SCHEMA_DEFERRED',
      generatedAt: '2026-09-20T02:00:00Z',
    ),
  );
}

class _ScreenshotNotificationRepository implements NotificationRepository {
  List<CourierNotification> notifications = _demoNotifications;

  @override
  Future<CourierNotificationPage> fetchNotifications({
    NotificationFilter filter = NotificationFilter.all,
    String category = 'all',
    int limit = 20,
    String? cursor,
  }) async {
    return CourierNotificationPage(
      items: notifications,
      generatedAt: DateTime.utc(2026, 11, 12, 2, 6),
    );
  }

  @override
  Future<int> fetchUnreadCount() async =>
      notifications.where((notification) => !notification.isRead).length;

  @override
  Future<CourierNotification> fetchDetail(String notificationId) async =>
      notifications.firstWhere(
        (notification) => notification.id == notificationId,
      );

  @override
  Future<CourierNotification> markRead(String notificationId) async {
    final notification = await fetchDetail(notificationId);
    final updated = notification.copyWith(
      readAt: DateTime.utc(2026, 11, 12, 2, 6),
    );
    notifications = [
      for (final item in notifications)
        if (item.id == notificationId) updated else item,
    ];
    return updated;
  }
}
