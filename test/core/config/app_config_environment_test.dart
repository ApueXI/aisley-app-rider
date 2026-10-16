import 'package:aisley_app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = '''
API_BASE_URL=http://10.0.2.2:8000
DEPLOYED_API_URL=https://deployed.example.test
''';

  group('API environment selection', () {
    for (final platform in TargetPlatform.values) {
      test('$platform debug/profile uses the local API', () {
        final config = AppConfig.fromDotEnv(
          source,
          isRelease: false,
          isWeb: false,
          platform: platform,
        );

        expect(
          config.endpoint('/courier/auth/me').toString(),
          'http://10.0.2.2:8000/api/v1/courier/auth/me',
        );
      });

      test('$platform browser release uses the local API', () {
        final config = AppConfig.fromDotEnv(
          source,
          isRelease: true,
          isWeb: true,
          platform: platform,
        );

        expect(config.baseUrl, 'http://10.0.2.2:8000');
      });
    }

    for (final platform in [
      TargetPlatform.fuchsia,
      TargetPlatform.iOS,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      test('$platform native release uses the local API', () {
        final config = AppConfig.fromDotEnv(
          source,
          isRelease: true,
          isWeb: false,
          platform: platform,
        );

        expect(config.baseUrl, 'http://10.0.2.2:8000');
      });
    }

    test('default debug loading keeps the local API on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(AppConfig.fromDotEnv(source).baseUrl, 'http://10.0.2.2:8000');
    });

    test('release selection uses the runtime platform by default', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        AppConfig.fromDotEnv(source, isRelease: true).baseUrl,
        'https://deployed.example.test',
      );
    });

    test('local defaults work without a deployed API', () {
      for (final isRelease in [false, true]) {
        final config = AppConfig.fromDotEnv(
          '',
          isRelease: isRelease,
          platform: TargetPlatform.linux,
        );
        expect(config.baseUrl, 'http://127.0.0.1:8000');
      }
      expect(
        AppConfig.fromDotEnv(
          'DEPLOYED_API_URL=invalid',
          platform: TargetPlatform.android,
        ).baseUrl,
        'http://127.0.0.1:8000',
      );
    });

    test('an Android browser release does not require a deployed API', () {
      final config = AppConfig.fromDotEnv(
        '',
        isRelease: true,
        isWeb: true,
        platform: TargetPlatform.android,
      );

      expect(config.baseUrl, 'http://127.0.0.1:8000');
    });
  });

  group('Android release configuration', () {
    for (final deployed in [
      null,
      '',
      '"  "',
      'not-a-url',
      'http://deployed.example.test',
      'http://127.0.0.1:8000',
      '//deployed.example.test',
      'https://',
      'https://[invalid',
      'https://deployed.example.test:invalid',
      'https://deployed.example.test:65536',
      'https://public-user@deployed.example.test',
      'https://deployed.example.test/api/v1',
      'https://deployed.example.test?option=value',
      'https://deployed.example.test#section',
      'https://invalid host.example.test',
    ]) {
      test('rejects invalid deployed origin: $deployed', () {
        final configSource =
            'API_BASE_URL=http://127.0.0.1:8000\n'
            '${deployed == null ? '' : 'DEPLOYED_API_URL=$deployed\n'}';

        expect(
          () => AppConfig.fromDotEnv(
            configSource,
            isRelease: true,
            isWeb: false,
            platform: TargetPlatform.android,
          ),
          throwsA(
            isA<FormatException>()
                .having((error) => error.source, 'source', isNull)
                .having(
                  (error) => error.message,
                  'message',
                  'DEPLOYED_API_URL must be an HTTPS origin in .env.',
                ),
          ),
        );
      });
    }

    test('supports quoted origins, comments, ports and trailing slashes', () {
      final config = AppConfig.fromDotEnv(
        'API_BASE_URL=invalid\n'
        'export DEPLOYED_API_URL = " https://deployed.example.test:8443/ " # Public\n',
        isRelease: true,
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(
        config.endpoint('courier/pickups', {'cursor': 'a+b'}).toString(),
        'https://deployed.example.test:8443/api/v1/courier/pickups?cursor=a%2Bb',
      );
    });
  });
}
