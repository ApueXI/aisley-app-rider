import 'dart:convert';

import 'package:flutter/services.dart';

class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.mapsEnabled = true,
    this.geoapifyApiKey = '',
    this.storefrontOrigin = '',
  });

  factory AppConfig.fromDotEnv(String source) {
    final values = _parseDotEnv(source);
    final baseUrl = values['API_BASE_URL'] ?? '';
    final mapsEnabled = switch (values['MAPS_ENABLED']?.toLowerCase() ?? '') {
      '' || 'true' || '1' => true,
      'false' || '0' => false,
      _ => throw const FormatException('Invalid MAPS_ENABLED in .env.'),
    };

    return AppConfig(
      baseUrl: baseUrl.isEmpty ? 'http://127.0.0.1:8000' : baseUrl,
      mapsEnabled: mapsEnabled,
      geoapifyApiKey: values['GEOAPIFY_API_KEY'] ?? '',
      storefrontOrigin: values['STOREFRONT_ORIGIN'] ?? '',
    );
  }

  static Future<AppConfig> load({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(
      '.env',
      cache: false,
    );
    return AppConfig.fromDotEnv(source);
  }

  static const apiPrefix = '/api/v1';

  final String baseUrl;
  final bool mapsEnabled;
  final String geoapifyApiKey;
  final String storefrontOrigin;

  Uri endpoint(String path, [Map<String, String>? queryParameters]) {
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$apiPrefix$normalizedPath');

    if (uri.scheme != 'https' && !_isLocalHost(uri.host)) {
      throw StateError('Non-local API endpoints must use HTTPS.');
    }

    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  static bool _isLocalHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2';
  }
}

Map<String, String> _parseDotEnv(String source) {
  const supportedKeys = {
    'MAPS_ENABLED',
    'GEOAPIFY_API_KEY',
    'API_BASE_URL',
    'STOREFRONT_ORIGIN',
  };
  final values = <String, String>{};
  for (var line in const LineSplitter().convert(
    source.replaceFirst('\uFEFF', ''),
  )) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final separator = line.indexOf('=');
    final key = (separator < 0 ? line : line.substring(0, separator)).trim();
    if (!supportedKeys.contains(key)) continue;
    if (separator < 0) throw FormatException('Invalid $key in .env.');

    var value = line.substring(separator + 1).trim();
    if (value.startsWith('"') || value.startsWith("'")) {
      final quote = value[0];
      final end = value.indexOf(quote, 1);
      final trailing = end < 0 ? '' : value.substring(end + 1).trim();
      if (end < 0 || (trailing.isNotEmpty && !trailing.startsWith('#'))) {
        throw FormatException('Invalid $key in .env.');
      }
      value = value.substring(1, end);
    } else {
      value = value.replaceFirst(RegExp(r'(^|\s+)#.*$'), '').trim();
    }
    values[key] = value;
  }
  return values;
}
