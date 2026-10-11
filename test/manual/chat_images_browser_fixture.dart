// Actual media widgets with synthetic selection/storage; no live API or credentials.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:aisley_app/core/chat_media/attachment.dart';
import 'package:aisley_app/core/chat_media/draft_controller.dart';
import 'package:aisley_app/core/chat_media/image_widgets.dart';
import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';

late SemanticsHandle semantics;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  runApp(const Fixture());
}

class Fixture extends StatefulWidget {
  const Fixture({super.key});
  @override
  State<Fixture> createState() => FixtureState();
}

class FixtureState extends State<Fixture> {
  late final MediaRepository repository = MediaRepository(
    Uri.base.queryParameters['scenario'] ?? 'normal',
  );
  late final media = ChatMediaDraftController(repository);
  final text = TextEditingController();
  late final auth =
      AuthController(authRepository: _Auth(), dashboardRepository: _Dashboard())
        ..status = AuthStatus.authenticated
        ..courier = CourierIdentity.fromJson({
          'id': 'courier-1',
          'email': 'courier@example.test',
          'role': 'courier',
          'status': 'active',
          'profile': {'first_name': 'Ana', 'last_name': 'Courier'},
          'logistics': {
            'status': 'approved',
            'organization': 'Synthetic Logistics',
            'hub': 'Demo hub',
          },
        });

  bool pending = false;
  String? caption, key;
  List<String>? ids;
  int sends = 0;
  final large = Uri.base.queryParameters['text'] == 'large';
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  final role = Uri.base.queryParameters['role'] ?? 'shop';
  @override
  void dispose() {
    auth.dispose();
    media.dispose();
    text.dispose();
    semantics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildCourierTheme(Brightness.light),
    darkTheme: buildCourierTheme(Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
      child: child!,
    ),
    home: repository.scenario == 'dashboard'
        ? DashboardScreen(authController: auth)
        : Scaffold(
            appBar: AppBar(title: Text('Private chat images · $role')),
            body: ListenableBuilder(
              listenable: media,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Confirmed sends: $sends'),
                  const Text('Received image'),
                  PrivateChatImage(
                    attachment: repository.received,
                    controller: media,
                  ),
                  ChatImageComposer(
                    controller: media,
                    contextValue: {
                      'channel': role,
                      'context_id': '11111111-1111-4111-8111-111111111111',
                    },
                    enabled: !pending,
                  ),
                  TextField(
                    controller: text,
                    enabled: !pending,
                    decoration: const InputDecoration(labelText: 'Caption'),
                  ),
                  FilledButton(
                    onPressed: !media.ready
                        ? null
                        : () {
                            setState(() {
                              if (!pending) {
                                caption = text.text;
                                ids = media.ids;
                                key = 'frozen-send';
                              }
                              if (repository.scenario == 'lost' && !pending) {
                                pending = true;
                                media.locked = true;
                              } else {
                                pending = false;
                                sends++;
                                media.clear();
                                text.clear();
                              }
                            });
                          },
                    child: Text(
                      pending ? 'Retry exact message' : 'Send message',
                    ),
                  ),
                  if (pending)
                    const Text(
                      'Message unconfirmed. Original caption, image IDs and key are frozen.',
                    ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      media.clear();
                      text.clear();
                      pending = false;
                    }),
                    child: const Text('Clear private session'),
                  ),
                ],
              ),
            ),
          ),
  );
}

class MediaRepository implements ChatMediaRepository {
  MediaRepository(this.scenario);
  final String scenario;
  int uploads = 0, checks = 0;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAEklEQVR4nGMQKl/wHx9mGBkKAM8iigGRRz6+AAAAAElFTkSuQmCC',
  );
  ChatAttachment asset(String state) => ChatAttachment(
    id: '11111111-1111-4111-8111-111111111111',
    kind: 'image',
    filename: 'Chat photo.png',
    mimeType: 'image/png',
    byteSize: png.length,
    state: state,
    previewUrl: '/api/v1/courier/chat-attachments/11111111-1111-4111-8111-111111111111/preview',
    contentUrl: '/api/v1/courier/chat-attachments/11111111-1111-4111-8111-111111111111/content',
  );
  ChatAttachment get received => asset('ready');
  @override
  Future<bool> capabilities() async => scenario != 'disabled';
  @override
  Future<SelectedChatImage?> pick() async =>
      SelectedChatImage(png, 'image.png', 'image/png');
  @override
  Future<ChatAttachment> upload(
    SelectedChatImage image,
    Map<String, Object?> context,
    String key,
  ) async {
    uploads++;
    if (scenario == 'upload_lost' && uploads == 1) {
      throw const ChatMediaFailure(
        'Upload unconfirmed. Retry the original request.',
      );
    }
    return asset(scenario == 'checking' ? 'pending' : 'ready');
  }

  @override
  Future<ChatAttachment> status(String id) async {
    checks++;
    return asset('ready');
  }

  @override
  Future<ChatAttachment> retry(String id) async => asset('ready');
  @override
  Future<void> remove(String id) async {}
  @override
  Future<Uint8List> image(String url) async {
    if (scenario == 'offline') {
      throw const ChatMediaFailure('Image unavailable.');
    }
    return png;
  }
}

class _Auth implements AuthRepository {
  @override
  Future<void> logout() async {}
  @override
  Future<void> clearStoredToken() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Dashboard implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async =>
      DashboardSnapshot.fromResponse(
        jsonDecode(
          r'''{"data": [], "meta": {"version": 2, "next_cursor": null, "generated_at": "2026-10-11T00:00:00.000000Z"}, "sections": {"notifications": {"state": "empty", "reason": null, "data": [], "has_more": false, "generated_at": "2026-10-11T00:00:00.000000Z"}, "available_tasks": {"state": "available", "reason": null, "data": [{"id": "11111111-1111-4111-8111-111111111111", "leg": "first_mile", "status": "assigned", "revision": null, "order_reference": "ORD-SYNTHETIC", "waybill_reference": "WB-SYNTHETIC", "schedule_id": "11111111-1111-4111-8111-111111111111", "created_at": "2026-10-11T00:00:00.000000Z"}], "has_more": false, "generated_at": "2026-10-11T00:00:00.000000Z"}, "active_tasks": {"state": "available", "reason": null, "data": [{"id": "11111111-1111-4111-8111-111111111111", "leg": "final_mile", "status": "in_transit", "revision": 3, "order_reference": "ORD-SYNTHETIC", "waybill_reference": "WB-SYNTHETIC", "schedule_id": null, "created_at": "2026-10-11T00:00:00.000000Z"}], "has_more": false, "generated_at": "2026-10-11T00:00:00.000000Z"}}, "freshness": {"state": "fresh", "reason": null, "generated_at": "2026-10-11T00:00:00.000000Z"}}''',
        ) as Map<String, dynamic>,
      );
}
