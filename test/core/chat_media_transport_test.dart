import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aisley_app/core/chat_media/api_repository.dart';
import 'package:aisley_app/core/chat_media/attachment.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';

const id = '11111111-1111-4111-8111-111111111111';
const asset = {
  'id': id,
  'kind': 'image',
  'filename': 'image.png',
  'mime_type': 'image/png',
  'byte_size': 3,
  'state': 'ready',
};

class Storage implements TokenStorage {
  @override
  Future<String?> read() async => 'synthetic-token';
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

ApiClient client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: Storage(),
      client: MockClient(handler),
    );
void main() {
  test('upload uses exact multipart context/key and bearer; private images reject foreign URLs', () async {
    final requests = <http.Request>[];
    final repo = ApiChatMediaRepository(
      client((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'data': asset}), 201);
        }
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    );
    await repo.upload(
      SelectedChatImage(
        Uint8List.fromList([1, 2, 3]),
        'image.png',
        'image/png',
      ),
      {'conversation_id': id},
      id,
    );
    expect(requests.single.url.path, '/api/v1/courier/chat-attachments');
    expect(requests.single.headers['authorization'], 'Bearer synthetic-token');
    expect(requests.single.headers['idempotency-key'], id);
    expect(requests.single.body, contains('name="context"'));
    expect(requests.single.body, contains('"conversation_id":"$id"'));
    expect(requests.single.body, contains('name="file"; filename="image.png"'));
    await repo.image('/api/v1/courier/chat-attachments/$id/preview');
    expect(requests.last.followRedirects, isFalse);
    await expectLater(
      repo.image('https://evil.test/image'),
      throwsA(isA<ChatMediaFailure>()),
    );
    expect(requests.length, 2);
  });
  test(
    'obsolete media denial does not clear a newer authenticated session',
    () async {
      final delayed = Completer<http.Response>();
      var generation = 0, denials = 0;
      final repo = ApiChatMediaRepository(
        client((_) => delayed.future),
        generation: () => generation,
        onDenial: (_) async {
          denials++;
        },
      );
      final read = repo.capabilities();
      generation++;
      delayed.complete(
        http.Response(
          jsonEncode({'message': 'Denied', 'code': 'UNAUTHENTICATED'}),
          401,
        ),
      );
      await expectLater(read, throwsA(isA<ChatMediaFailure>()));
      expect(denials, 0);
    },
  );
}
