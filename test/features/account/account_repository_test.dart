import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/account/data/account_repository.dart';
import 'package:aisley_app/features/account/domain/account_models.dart';

void main() {
  test('requests a password verification code with authenticated POST and exact fields', () async {
    late http.Request request;
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'synthetic-token',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'message': 'Queued',
            'data': {
              'challenge_id': '11111111-1111-4111-8111-111111111111',
              'masked_email': 'r***@example.test',
              'expires_at': '2026-10-14T10:10:00Z',
              'resend_available_at': '2026-10-14T10:01:00Z',
            },
          }),
          202,
        );
      }),
    );
    final result = await ApiAccountRepository(client: client)
        .requestPasswordCode(
          currentPassword: 'Synthetic123',
          password: 'Synthetic456',
          passwordConfirmation: 'Synthetic456',
        );
    expect(result.id, '11111111-1111-4111-8111-111111111111');
    expect(result.maskedEmail, 'r***@example.test');
    expect(request.method, 'POST');
    expect(
      request.url.path,
      '/api/v1/courier/account/password/verification-code',
    );
    expect(jsonDecode(request.body), {
      'current_password': 'Synthetic123',
      'password': 'Synthetic456',
      'password_confirmation': 'Synthetic456',
    });
    expect(request.headers['Authorization'], 'Bearer synthetic-token');
  });

  test('reads the authenticated Courier account projection', () async {
    late http.Request request;
    final storage = _FakeTokenStorage()..token = 'account-token';
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_accountResponse), 200);
      }),
    );
    final repository = ApiAccountRepository(client: client);

    final account = await repository.fetchAccount();

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/account');
    expect(request.headers['authorization'], 'Bearer account-token');
    expect(account.email, 'courier@example.com');
    expect(account.profile.firstName, 'Ana');
    expect(account.affiliation.hubName, 'Main Hub');
    expect(account.security.emailEditable, isFalse);
  });

  test('updates only the documented profile fields', () async {
    late http.Request request;
    final storage = _FakeTokenStorage()..token = 'account-token';
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_accountResponse), 200);
      }),
    );
    final repository = ApiAccountRepository(client: client);

    await repository.updateProfile(
      firstName: ' Ana ',
      middleName: ' ',
      lastName: ' Santos ',
      contactNumber: ' 09171234567 ',
      idempotencyKey: 'profile-save-1',
    );

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(request.method, 'PATCH');
    expect(request.url.path, '/api/v1/courier/account/profile');
    expect(request.headers['authorization'], 'Bearer account-token');
    expect(request.headers['idempotency-key'], 'profile-save-1');
    expect(body, <String, dynamic>{
      'first_name': 'Ana',
      'middle_name': null,
      'last_name': 'Santos',
      'contact_number': '09171234567',
    });
    expect(body.keys, isNot(contains('email')));
    expect(body.keys, isNot(contains('role')));
    expect(body.keys, isNot(contains('status')));
    expect(body.keys, isNot(contains('hub_id')));
  });

  test('changes the password with the exact credential fields', () async {
    late http.Request request;
    final storage = _FakeTokenStorage()..token = 'account-token';
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response('', 200);
      }),
    );
    final repository = ApiAccountRepository(client: client);

    await repository.changePassword(
      currentPassword: 'old-secret',
      password: 'new-secret',
      passwordConfirmation: 'new-secret',
      challengeId: '00000000-0000-4000-8000-000000000001',
      verificationCode: '123456',
    );

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/courier/account/password');
    expect(body.keys, <String>{
      'current_password',
      'password',
      'password_confirmation',
      'challenge_id',
      'verification_code',
    });
    expect(body.keys, isNot(contains('token')));
    expect(body.keys, isNot(contains('role')));
    expect(body.keys, isNot(contains('remember')));
  });

  test(
    'uploads the photo as the documented authenticated multipart field',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'aisley_profile_photo_test_',
      );
      addTearDown(() async {
        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      });
      final photo = File('${temporaryDirectory.path}/courier.png');
      await photo.writeAsBytes(<int>[0x89, 0x50, 0x4e, 0x47]);

      late http.Request request;
      final storage = _FakeTokenStorage()..token = 'account-token';
      final client = ApiClient(
        config: const AppConfig(baseUrl: 'https://api.example.test'),
        tokenStorage: storage,
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(jsonEncode(_accountResponse), 200);
        }),
      );
      final repository = ApiAccountRepository(client: client);

      await repository.uploadProfilePhoto(
        selection: ProfilePhotoSelection(
          path: photo.path,
          fileName: 'courier.png',
          bytes: Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47]),
        ),
        idempotencyKey: 'photo-upload-1',
      );

      final body = String.fromCharCodes(request.bodyBytes);
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/courier/account/profile-photo');
      expect(request.headers['authorization'], 'Bearer account-token');
      expect(request.headers['idempotency-key'], 'photo-upload-1');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(body, contains('name="photo"'));
      expect(body, contains('filename="courier.png"'));
      expect(body, isNot(contains('courier_id')));
      expect(body, isNot(contains('profile_photo_path')));
    },
  );

  test('fetches the private photo URL with the bearer token', () async {
    late http.Request request;
    final storage = _FakeTokenStorage()..token = 'account-token';
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response.bytes(
          <int>[1, 2, 3],
          200,
          headers: const <String, String>{'content-type': 'image/png'},
        );
      }),
    );
    final repository = ApiAccountRepository(client: client);

    final photo = await repository.fetchProfilePhoto(
      '/api/v1/courier/account/profile-photo?v=photo-1',
    );

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/account/profile-photo');
    expect(request.url.queryParameters['v'], 'photo-1');
    expect(request.headers['authorization'], 'Bearer account-token');
    expect(photo.contentType, 'image/png');
    expect(photo.bytes, <int>[1, 2, 3]);
  });

  test('deletes the current private photo through the exact route', () async {
    late http.Request request;
    final storage = _FakeTokenStorage()..token = 'account-token';
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response('', 204);
      }),
    );
    final repository = ApiAccountRepository(client: client);

    await repository.deleteProfilePhoto();

    expect(request.method, 'DELETE');
    expect(request.url.path, '/api/v1/courier/account/profile-photo');
    expect(request.headers['authorization'], 'Bearer account-token');
  });

  test(
    'rejects a profile photo URL outside the configured API origin',
    () async {
      var requestWasMade = false;
      final storage = _FakeTokenStorage()..token = 'account-token';
      final client = ApiClient(
        config: const AppConfig(baseUrl: 'https://api.example.test'),
        tokenStorage: storage,
        client: MockClient((incoming) async {
          requestWasMade = true;
          return http.Response.bytes(<int>[1], 200);
        }),
      );
      final repository = ApiAccountRepository(client: client);

      expect(
        () => repository.fetchProfilePhoto(
          'https://other.example.test/api/v1/courier/account/profile-photo',
        ),
        throwsA(isA<ApiContractException>()),
      );
      expect(requestWasMade, isFalse);
    },
  );
}

class _FakeTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

const _accountResponse = <String, dynamic>{
  'account': <String, dynamic>{
    'id': 'courier-1',
    'email': 'courier@example.com',
    'role': 'courier',
    'status': 'active',
    'profile': <String, dynamic>{
      'first_name': 'Ana',
      'middle_name': null,
      'last_name': 'Santos',
      'contact_number': '09171234567',
      'sex': 'female',
      'birth_date': '1999-01-01',
      'age': 27,
      'profile_photo_url': null,
    },
    'affiliation': <String, dynamic>{
      'status': 'approved',
      'organization_name': 'Aisley Express',
      'hub_name': 'Main Hub',
    },
    'security': <String, dynamic>{
      'email_editable': false,
      'profile_photo_editable': true,
      'password_change_requires_current_password': true,
    },
  },
};
