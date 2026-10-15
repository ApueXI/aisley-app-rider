import 'dart:convert';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig dotenv', () {
    test('loads all four public values from the .env asset', () async {
      final bundle = _ConfigBundle('''
MAPS_ENABLED=false
GEOAPIFY_API_KEY=public-test-key
API_BASE_URL=https://api.example.test
STOREFRONT_ORIGIN=https://shop.example.test
''');

      final config = await AppConfig.load(bundle: bundle);

      expect(bundle.requests, ['.env']);
      expect(config.mapsEnabled, isFalse);
      expect(config.geoapifyApiKey, 'public-test-key');
      expect(config.storefrontOrigin, 'https://shop.example.test');
      expect(
        config.endpoint('/courier/auth/me').toString(),
        'https://api.example.test/api/v1/courier/auth/me',
      );
    });

    test('blank and absent values retain the existing local defaults', () {
      for (final source in [
        '',
        'MAPS_ENABLED=\nGEOAPIFY_API_KEY=\nAPI_BASE_URL=\nSTOREFRONT_ORIGIN=\n',
      ]) {
        final config = AppConfig.fromDotEnv(source);
        expect(config.baseUrl, 'http://127.0.0.1:8000');
        expect(config.mapsEnabled, isTrue);
        expect(config.geoapifyApiKey, isEmpty);
        expect(config.storefrontOrigin, isEmpty);
      }
    });

    test('supports BOM, CRLF, export, quotes, whitespace and comments', () {
      final config = AppConfig.fromDotEnv(
        '\uFEFF# Public client configuration\r\n'
        'export MAPS_ENABLED = "false" # Disabled locally\r\n'
        "API_BASE_URL = 'https://api.example.test/'\r\n"
        'GEOAPIFY_API_KEY="public#key=value"\r\n'
        'STOREFRONT_ORIGIN=https://shop.example.test # Optional\r\n',
      );

      expect(config.mapsEnabled, isFalse);
      expect(config.geoapifyApiKey, 'public#key=value');
      expect(config.storefrontOrigin, 'https://shop.example.test');
      expect(
        config.endpoint('courier/auth/me').toString(),
        'https://api.example.test/api/v1/courier/auth/me',
      );
    });

    test('does not treat URL fragments as comments or expand variables', () {
      final config = AppConfig.fromDotEnv(
        r'GEOAPIFY_API_KEY=public#key=${LITERAL}'
        '\n'
        'STOREFRONT_ORIGIN=https://shop.example.test/#orders\n',
      );

      expect(config.geoapifyApiKey, r'public#key=${LITERAL}');
      expect(config.storefrontOrigin, 'https://shop.example.test/#orders');
    });

    test('ignores unrelated keys and uses the last duplicate value', () {
      final config = AppConfig.fromDotEnv('''
OTHER_SETTING="unclosed
API_BASE_URL=https://old.example.test
API_BASE_URL=https://api.example.test
''');
      expect(config.baseUrl, 'https://api.example.test');
    });

    for (final value in ['true', 'TRUE', '1', 'false', 'FALSE', '0']) {
      test('parses MAPS_ENABLED=$value', () {
        expect(
          AppConfig.fromDotEnv('MAPS_ENABLED=$value').mapsEnabled,
          ['true', 'TRUE', '1'].contains(value),
        );
      });
    }

    for (final source in [
      'MAPS_ENABLED=unsupported-value',
      'API_BASE_URL',
      'GEOAPIFY_API_KEY="unclosed-public-value',
      'STOREFRONT_ORIGIN="https://shop.example.test" trailing-value',
    ]) {
      test('rejects malformed configuration without exposing values: '
          '${source.split('=').first}', () {
        expect(
          () => AppConfig.fromDotEnv(source),
          throwsA(
            isA<FormatException>()
                .having((error) => error.source, 'source', isNull)
                .having(
                  (error) => error.toString(),
                  'message',
                  allOf(
                    isNot(contains('unsupported-value')),
                    isNot(contains('unclosed-public-value')),
                    isNot(contains('https://shop.example.test')),
                  ),
                ),
          ),
        );
      });
    }

    test('missing .env fails instead of silently selecting another API', () {
      expect(
        AppConfig.load(bundle: _ConfigBundle(null)),
        throwsA(isA<FlutterError>()),
      );
    });

    test('retry rereads the asset after a configuration error', () async {
      final bundle = _ConfigBundle('MAPS_ENABLED=invalid');
      await expectLater(AppConfig.load(bundle: bundle), throwsFormatException);
      bundle.source = 'API_BASE_URL=https://api.example.test';

      expect(
        (await AppConfig.load(bundle: bundle)).baseUrl,
        'https://api.example.test',
      );
      expect(bundle.requests, ['.env', '.env']);
    });

    test('API requests retain the HTTPS restriction and query encoding', () {
      final insecure = AppConfig.fromDotEnv(
        'API_BASE_URL=http://api.example.test',
      );
      expect(() => insecure.endpoint('/courier/auth/me'), throwsStateError);

      final emulator = AppConfig.fromDotEnv(
        'API_BASE_URL=http://10.0.2.2:8000/',
      );
      expect(
        emulator.endpoint('/courier/pickups', {'cursor': 'a+b'}).toString(),
        'http://10.0.2.2:8000/api/v1/courier/pickups?cursor=a%2Bb',
      );
    });
  });
}

class _ConfigBundle extends CachingAssetBundle {
  _ConfigBundle(this.source);

  String? source;
  final requests = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requests.add(key);
    final value = source;
    if (key != '.env' || value == null) throw FlutterError('Missing config.');
    return ByteData.sublistView(utf8.encode(value));
  }
}
