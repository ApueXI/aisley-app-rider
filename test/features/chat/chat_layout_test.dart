import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/chat_thread_screen.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fixtures/registration_screen_fixture.dart';

const thread = ChatThread(
  id: 'thread-1',
  kind: 'logistics_courier',
  leg: 'first_mile',
  taskId: 'task-1',
  taskReference: 'ORD-SYNTHETIC',
  counterpartyRole: 'logistics',
  counterpartyLabel: 'Test Logistics',
  unreadCount: 0,
  lastSequence: 0,
  lastReadSequence: 0,
  sendAllowed: true,
);

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('chat composer keyboard $width $scale ${brightness.name}', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, width == 320 ? 640 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final controller = _LayoutController();
          final auth = _auth();
          await _open(
            tester,
            controller,
            auth,
            brightness: brightness,
            scale: scale,
          );
          await tester.enterText(
            find.byType(TextField),
            'First line\nSecond line\nThird line\nFourth line',
          );
          controller.showRecovery();
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('Message not confirmed'), findsOneWidget);
          expect(find.byTooltip('Send message'), findsNothing);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.labelText == 'Message',
            ),
            findsNothing,
          );
          await tester.ensureVisible(find.text('Retry same message'));
          expect(
            tester.getRect(find.text('Retry same message')).bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height - 280),
          );
          expect(find.byTooltip('Back'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          auth.dispose();
        });
      }
    }
  }
  testWidgets('fresh text immediately protects system Back', (tester) async {
    final controller = _LayoutController(), auth = _auth();
    await _open(tester, controller, auth);
    controller.stopPolling();
    await tester.enterText(find.byType(TextField), 'Unsent draft');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsent draft'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open thread'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });
}

Future<void> _open(
  WidgetTester tester,
  ChatController controller,
  AuthController auth, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCourierTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatThreadScreen(
                  controller: controller,
                  authController: auth,
                  thread: thread,
                ),
              ),
            ),
            child: const Text('Open thread'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open thread'));
  await tester.pumpAndSettle();
}

AuthController _auth() =>
    AuthController(
        authRepository: RegistrationTestRepository(),
        dashboardRepository: _UnusedDashboard(),
      )
      ..status = AuthStatus.authenticated
      ..courier = const CourierIdentity(
        id: 'courier-1',
        email: 'courier@example.com',
        role: 'courier',
        status: CourierAccountStatus.active,
      );

class _UnusedDashboard implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _LayoutController extends ChatController {
  _LayoutController() : super(repository: _ChatRepository());
  void showRecovery() {
    sendError =
        'This message could not be confirmed. Check the conversation before retrying. '
        'Your previous text and selected images will be used for the same message.';
    sendStatus = ChatSendStatus.uncertain;
    unresolvedSend = true;
    pendingAttempt = const ChatSendAttempt(
      body: 'First line\nSecond line\nThird line\nFourth line',
      key: '11111111-1111-4111-8111-111111111111',
      leg: 'first_mile',
      taskId: 'task-1',
      counterpartyRole: 'logistics',
      threadId: 'thread-1',
    );
    notifyListeners();
  }
}

class _ChatRepository implements ChatRepository {
  @override
  Future<ChatThread> detail(String id) async => thread;
  @override
  Future<ChatPage<ChatMessage>> messages(
    String id, {
    String? cursor,
    int limit = 20,
  }) async => const ChatPage(items: [], nextCursor: null);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
