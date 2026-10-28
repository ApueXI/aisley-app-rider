import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/auth/presentation/login_screen.dart';
import 'package:aisley_app/features/auth/presentation/registration_screen.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/chat_inbox_screen.dart';
import 'package:aisley_app/features/chat/presentation/chat_thread_screen.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:aisley_app/features/history/domain/history_models.dart';
import 'package:aisley_app/features/history/presentation/controllers/history_controller.dart';
import 'package:aisley_app/features/history/presentation/history_screen.dart';
import 'package:aisley_app/features/notification/data/notification_repository.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:aisley_app/features/notification/presentation/notification_screen.dart';
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
    'registration-email',
    'messages',
    'thread-unresolved',
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
        await _capture(tester, boundary, screen);
        await tester.pumpWidget(const SizedBox.shrink());
        authFixture.auth.dispose();
      } else if (screen == 'registration-email') {
        await _captureRegistrationEmail(tester, boundary);
      } else if (screen == 'messages') {
        final authFixture = RegistrationScreenFixture();
        final auth = _activate(authFixture.auth);
        final chat = ChatController(repository: _ScreenshotChatRepository());
        await _pumpCaptureApp(
          tester,
          boundary,
          ChatInboxScreen(controller: chat, authController: auth),
        );
        await tester.pumpAndSettle();
        await _capture(tester, boundary, screen);
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        auth.dispose();
      } else if (screen == 'thread-unresolved') {
        final authFixture = RegistrationScreenFixture();
        final auth = _activate(authFixture.auth);
        final chat =
            ChatController(
                repository: _ScreenshotChatRepository(
                  includeCourierReply: false,
                ),
              )
              ..pendingAttempt = const ChatSendAttempt(
                body: 'I am at the hub entrance.',
                key: '00000000-0000-4000-8000-000000000001',
                leg: 'first_mile',
                taskId: 'task-demo-2048',
                counterpartyRole: 'logistics',
                threadId: 'conversation-demo-2048',
              )
              ..unresolvedSend = true
              ..sendStatus = ChatSendStatus.uncertain
              ..sendError =
                  'The message may not have been saved. Retry this exact message.';
        await _pumpCaptureApp(
          tester,
          boundary,
          ChatThreadScreen(
            controller: chat,
            authController: auth,
            thread: _demoThread,
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, boundary, screen);
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        auth.dispose();
      } else if (screen == 'history') {
        final repository = history.HistorySearchRepository()
          ..page = DeliveryHistoryPage(items: [_demoHistoryItem]);
        final controller = HistoryController(historyRepository: repository);
        final auth = history.historyAuth();
        await _pumpCaptureApp(
          tester,
          boundary,
          HistoryScreen(authController: auth, historyController: controller),
        );
        await tester.pumpAndSettle();
        await _capture(tester, boundary, screen);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        auth.dispose();
      } else if (screen == 'notifications') {
        final repository = _ScreenshotNotificationRepository();
        final controller = NotificationController(
          notificationRepository: repository,
        );
        await _pumpCaptureApp(
          tester,
          boundary,
          NotificationScreen(controller: controller, managePolling: false),
        );
        await tester.pumpAndSettle();
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

Future<void> _captureRegistrationEmail(
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

  final fixture = RegistrationScreenFixture();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCourierTheme(Brightness.light),
      home: RepaintBoundary(
        key: boundary,
        child: RegistrationScreen(
          authController: fixture.auth,
          onSignIn: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await registration.enter(tester, 'Email address', 'courier@example.test');
  await tester.ensureVisible(find.text('Send verification code'));
  await tester.tap(find.text('Send verification code'));
  await tester.pumpAndSettle();
  await _capture(tester, boundary, 'registration-email');
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
    final folder = Directory('build/stitch-ui/identity');
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    image.dispose();
  });
}

const _demoThread = ChatThread(
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

final _demoNotification = CourierNotification(
  id: 'notification-demo-2048',
  type: 'courier-task.final-mile-offered',
  title: 'Delivery offered',
  summary: 'A delivery request is available.',
  createdAt: DateTime.utc(2026, 9, 20, 2),
  resourceType: 'delivery_task',
  resourceId: 'task-demo-2048',
  destination: '/delivery-tasks/task-demo-2048',
);

class _ScreenshotChatRepository implements ChatRepository {
  _ScreenshotChatRepository({this.includeCourierReply = true});

  final bool includeCourierReply;

  @override
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  }) async => ChatPage<ChatThread>(
    items: const [_demoThread],
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
  }) async {
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'message-demo-1',
        conversationId: 'conversation-demo-2048',
        sequence: 1,
        senderRole: 'logistics',
        mine: false,
        body: 'Please confirm when you arrive at the hub.',
        createdAt: DateTime.utc(2026, 9, 20, 1, 50),
      ),
    ];
    if (includeCourierReply) {
      messages.add(
        ChatMessage(
          id: 'message-demo-2',
          conversationId: 'conversation-demo-2048',
          sequence: 2,
          senderRole: 'courier',
          mine: true,
          body: 'I am at the hub entrance.',
          createdAt: DateTime.utc(2026, 9, 20, 1, 55),
        ),
      );
    }
    return ChatPage<ChatMessage>(items: messages, nextCursor: null);
  }

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

class _ScreenshotNotificationRepository implements NotificationRepository {
  CourierNotification notification = _demoNotification;

  @override
  Future<CourierNotificationPage> fetchNotifications({
    NotificationFilter filter = NotificationFilter.all,
    String category = 'all',
    int limit = 20,
    String? cursor,
  }) async => CourierNotificationPage(
    items: [notification],
    generatedAt: DateTime.utc(2026, 9, 20, 2, 1),
  );

  @override
  Future<int> fetchUnreadCount() async => notification.isRead ? 0 : 1;

  @override
  Future<CourierNotification> fetchDetail(String notificationId) async =>
      notification;

  @override
  Future<CourierNotification> markRead(String notificationId) async =>
      notification = notification.copyWith(
        readAt: DateTime.utc(2026, 9, 20, 2, 1),
      );
}
