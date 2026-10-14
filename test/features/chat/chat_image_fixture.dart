import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/core/chat_media/draft_controller.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/chat_thread_screen.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/chat_image_identity.dart';

class ChatImageThreadFixture {
  ChatImageThreadFixture(String role)
    : repo = ChatImageHistoryRepository(role) {
    chat = ChatController(
      repository: repo,
      media: ChatMediaDraftController(images),
    );
    auth = AuthController(
      authRepository: _UnusedAuthRepository(),
      dashboardRepository: _UnusedDashboardRepository(),
      onSessionEnded: chat.clear,
    )..status = AuthStatus.authenticated;
  }
  final ChatImageHistoryRepository repo;
  final images = IdentityMediaFake();
  late final ChatController chat;
  late final AuthController auth;

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(chat.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCourierTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ChatThreadScreen(
          controller: chat,
          authController: auth,
          thread: repo.thread,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());
}

class ChatImageHistoryRepository implements ChatRepository {
  ChatImageHistoryRepository(String role)
    : thread = ChatThread(
        id: 'thread-1',
        kind: role == 'logistics' ? 'logistics_courier' : 'courier_$role',
        leg: role == 'customer' ? 'final_mile' : 'first_mile',
        taskId: 'task-1',
        counterpartyRole: role,
        counterpartyLabel: 'Counterpart',
        taskReference: 'TASK-1',
        unreadCount: 0,
        lastSequence: 2,
        lastReadSequence: 2,
        sendAllowed: true,
      );
  final ChatThread thread;
  ChatPage<ChatMessage> latest = const ChatPage(items: [], nextCursor: null);
  ChatPage<ChatMessage> older = const ChatPage(items: [], nextCursor: null);
  ApiException? error;
  final cursors = <String?>[];
  @override
  Future<ChatThread> detail(String id) async {
    if (error case final error?) throw error;
    return thread;
  }

  @override
  Future<ChatPage<ChatMessage>> messages(
    String id, {
    String? cursor,
    int limit = 20,
  }) async {
    cursors.add(cursor);
    return cursor == null ? latest : older;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected chat operation');
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  @override
  Future<void> logout() async {}
}

class _UnusedDashboardRepository implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
