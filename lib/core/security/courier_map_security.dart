import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../networking/api_client.dart';
import '../networking/api_contract_exception.dart';

/// MapLibre 0.27.1's Android header setter uses static global credentials and
/// its web setter is unimplemented. Authenticate tiles through ApiClient and
/// pass image bytes to per-map image sources instead. Never give the SDK tokens.
class CourierMapSecurity extends ChangeNotifier {
  CourierMapSecurity({required this._client, required AppConfig config})
    : tileOrigin = config.endpoint('/courier/map-tiles/');
  final ApiClient _client;
  final Uri tileOrigin;
  int _generation = 0;
  int get generation => _generation;

  static const emptyStyle =
      '{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#eeeeee"}}]}';

  bool acceptsTileUrl(String url, {bool template = false}) {
    if (template) return url == '$tileOrigin{z}/{x}/{y}.png';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != tileOrigin.scheme ||
        uri.host != tileOrigin.host ||
        uri.port != tileOrigin.port ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    final suffix = template
        ? r'\{z\}/\{x\}/\{y\}\.png'
        : r'[0-9]+/[0-9]+/[0-9]+\.png';
    return RegExp('^${RegExp.escape(tileOrigin.path)}$suffix\$')
        .hasMatch(uri.path);
  }

  /// Whitelist the implemented raster DTO, rejecting all alternate resource
  /// types, sprite/glyph URLs, imports, source URLs, and unexpected attributes.
  int validateStyle(Object? value) {
    if (value is! Map ||
        value['version'] != 8 ||
        value.keys.any(
          (k) => !{'version', 'name', 'sources', 'layers'}.contains(k),
        )) {
      throw const ApiContractException('map.style');
    }
    final sources = value['sources'];
    final layers = value['layers'];
    if (sources is! Map ||
        sources.length != 1 ||
        layers is! List ||
        layers.length != 1) {
      throw const ApiContractException('map.style.resources');
    }
    final source = sources.values.single;
    final layer = layers.single;
    if (source is! Map ||
        source['type'] != 'raster' ||
        source.keys.any(
          (k) => !{
            'type',
            'tiles',
            'tileSize',
            'maxzoom',
            'attribution',
          }.contains(k),
        ) ||
        source['tileSize'] != 256 ||
        layer is! Map ||
        layer['type'] != 'raster' ||
        layer['source'] != sources.keys.single ||
        layer.keys.any((k) => !{'id', 'type', 'source'}.contains(k))) {
      throw const ApiContractException('map.style.source');
    }
    final tiles = source['tiles'];
    final zoom = source['maxzoom'];
    if (tiles is! List ||
        tiles.length != 1 ||
        tiles.single is! String ||
        !acceptsTileUrl(tiles.single as String, template: true) ||
        zoom is! int ||
        zoom < 0 ||
        zoom > 18) {
      throw const ApiContractException('map.style.tiles');
    }
    return zoom;
  }

  Future<int> loadStyle() async {
    final epoch = _generation;
    final response = await _client.get(
      '/courier/map-style',
      followRedirects: false,
      authenticated: true,
      headers: const {'Cache-Control': 'no-store'},
    );
    if (epoch != _generation) throw const MapSessionEnded();
    try {
      return validateStyle(jsonDecode(response.body));
    } on FormatException {
      throw const ApiContractException('map.style.json');
    }
  }

  Future<Uint8List> tile(int z, int x, int y) async {
    if (z < 0 || z > 18 || x < 0 || y < 0 || x >= 1 << z || y >= 1 << z) {
      throw const ApiContractException('map.tile.coordinate');
    }
    final epoch = _generation;
    final url = tileOrigin.resolve('$z/$x/$y.png').toString();
    if (!acceptsTileUrl(url)) throw const ApiContractException('map.tile.url');
    final response = await _client.get(
      '/courier/map-tiles/$z/$x/$y.png',
      followRedirects: false,
      authenticated: true,
      headers: const {'Accept': 'image/png', 'Cache-Control': 'no-store'},
    );
    if (epoch != _generation) throw const MapSessionEnded();
    final bytes = response.bodyBytes;
    if (bytes.length < 8 ||
        bytes.length > 2 * 1024 * 1024 ||
        !listEquals(bytes.take(8).toList(), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ])) {
      throw const ApiContractException('map.tile.image');
    }
    return bytes;
  }

  void invalidate() {
    _generation++;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

class MapSessionEnded implements Exception {
  const MapSessionEnded();
}
