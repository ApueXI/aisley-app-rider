// Test-only entrypoint. Credentials come from the disposable loopback fixture,
// stay in memory, and are never compiled into the application or persisted.
import 'dart:math';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/core/chat_media/api_repository.dart';
import 'package:aisley_app/core/chat_media/attachment.dart';
import 'package:aisley_app/core/chat_media/draft_controller.dart';
import 'package:aisley_app/core/chat_media/media_platform.dart';
import 'package:aisley_app/core/chat_media/private_file.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';

late SemanticsHandle semantics;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  await cleanAbandonedChatMedia();
  runApp(
    MaterialApp(
      theme: buildCourierTheme(Brightness.light),
      home: const RuntimeFixture(),
    ),
  );
}

class RuntimeFixture extends StatefulWidget {
  const RuntimeFixture({super.key});
  @override
  State<RuntimeFixture> createState() => _RuntimeFixtureState();
}

class _RuntimeFixtureState extends State<RuntimeFixture> {
  ApiClient? api;
  final storage = _FixtureStorage();
  ChatMediaDraftController? media;
  List<ChatAttachment> attachments = [];
  String? conversation;
  String result = 'Connecting to isolated runtime…';
  bool active = true, busy = false;
  final bootstrap = http.Client();
  final sessionUrl = const String.fromEnvironment(
    'MEDIA_SESSION_URL',
    defaultValue: 'http://localhost:8765/fixture-session',
  );

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final uri = Uri.parse(sessionUrl);
      if (uri.scheme != 'http' ||
          !['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)) {
        throw const FormatException('Loopback fixture required');
      }
      final response = await bootstrap.get(Uri.parse(sessionUrl));
      if (!mounted || !active) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      var origin = data['api_origin'] as String;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        origin = Uri.parse(origin).replace(host: '10.0.2.2').origin;
      }
      storage.token = data['token'] as String;
      final client = ApiClient(
        config: AppConfig(baseUrl: origin),
        tokenStorage: storage,
      );
      await client.get('/courier/auth/me', authenticated: true);
      if (!mounted || !active) return;
      final repository = ApiChatMediaRepository(
        client,
        generation: () => active ? 0 : 1,
      );
      final allowed = await repository.capabilities();
      if (!mounted || !active || !allowed) throw StateError('Unavailable');
      setState(() {
        api = client;
        media = ChatMediaDraftController(repository);
        conversation = data['conversation_id'] as String;
        attachments = ChatAttachment.list(data['attachments']);
        result = 'Authenticated runtime ready';
      });
    } catch (_) {
      if (mounted && active) {
        setState(() => result = 'Runtime connection failed');
      }
    }
  }

  String _key() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _sendImage() async {
    if (busy || !active || media == null) return;
    setState(() => busy = true);
    try {
      final response = await bootstrap.get(
        Uri.parse(sessionUrl).resolve('/fixture-image'),
      );
      final repository = media!.repository;
      final image = SelectedChatImage(
        response.bodyBytes,
        'photo.png',
        'image/png',
      );
      var asset = await repository.upload(image, {
        'conversation_id': conversation,
      }, _key());
      for (var i = 0; i < 30 && asset.state == 'pending' && active; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        asset = await repository.status(asset.id);
      }
      if (!active || asset.state != 'ready') {
        throw StateError('Image not ready');
      }
      final key = _key();
      final chat = ApiChatRepository(client: api!);
      final first = await chat.send(
        id: conversation!,
        body: '',
        attachmentIds: [asset.id],
        idempotencyKey: key,
      );
      final replay = await chat.send(
        id: conversation!,
        body: '',
        attachmentIds: [asset.id],
        idempotencyKey: key,
      );
      if (first.message.id != replay.message.id) {
        throw StateError('Replay mismatch');
      }
      if (mounted && active) {
        setState(() => result = 'Image sent and replay verified');
      }
    } catch (_) {
      if (mounted && active) {
        setState(() => result = 'Runtime image check failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _logout() async {
    try {
      await api?.postJson('/courier/auth/logout', authenticated: true);
    } finally {
      active = false;
      await storage.clear();
      media?.clear();
      if (mounted) {
        setState(() {
          attachments = [];
          result = 'Runtime signed out';
        });
      }
    }
  }

  @override
  void dispose() {
    active = false;
    storage.token = null;
    media?.dispose();
    bootstrap.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('G26 local runtime')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(result),
        if (media != null && active) ...[
          for (final attachment in attachments)
            PrivateChatFile(attachment: attachment, controller: media!),
          TextButton(
            onPressed: busy ? null : _sendImage,
            child: const Text('Verify image send'),
          ),
          TextButton(onPressed: _logout, child: const Text('Sign out')),
        ],
      ],
    ),
  );
}

class _FixtureStorage implements TokenStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
