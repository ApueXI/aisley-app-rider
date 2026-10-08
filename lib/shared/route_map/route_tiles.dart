import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/security/courier_map_security.dart';

/// Bounded viewport image sources. A single failed request stops the loader;
/// only an explicit retry creates another loader. No snapshots or tile cache.
class RouteTiles {
  RouteTiles(this.security, this.map);
  final CourierMapSecurity security;
  final MapLibreMapController map;
  int maxZoom = 18;
  bool _busy = false;
  bool _pending = false;
  bool _stopped = false;
  int _version = 0;
  final Set<String> _visible = {};

  void stop() {
    _stopped = true;
    _version++;
    _visible.clear();
  }

  Future<void> update() async {
    if (_stopped) return;
    if (_busy) {
      _pending = true;
      return;
    }
    _pending = false;
    _busy = true;
    final epoch = _version;
    try {
      final bounds = await map.getVisibleRegion();
      var zoom = (map.cameraPosition?.zoom ?? 10).floor().clamp(0, maxZoom);
      var tiles = viewportTiles(bounds, zoom);
      while (tiles.length > 16 && zoom > 0) {
        tiles = viewportTiles(bounds, --zoom);
      }
      if (_stopped || epoch != _version) return;
      final needed = tiles.map((t) => t.id).toSet();
      for (final id in _visible.difference(needed).toList()) {
        await map.removeLayer('$id-layer');
        await map.removeSource(id);
        _visible.remove(id);
      }
      for (final tile in tiles) {
        if (_visible.contains(tile.id)) continue;
        final bytes = await security.tile(tile.z, tile.x, tile.y);
        if (_stopped || epoch != _version) return;
        if (kIsWeb) {
          // addImageSource(bytes) is not implemented on web in 0.27.1.
          // An inline image URL carries only raster pixels, never credentials.
          await map.addSource(
            tile.id,
            ImageSourceProperties(
              url: 'data:image/png;base64,${base64Encode(bytes)}',
              coordinates: tile.corners
                  .map((p) => [p.longitude, p.latitude])
                  .toList(),
            ),
          );
        } else {
          await map.addImageSource(
            tile.id,
            bytes,
            LatLngQuad(
              topLeft: tile.corners[0],
              topRight: tile.corners[1],
              bottomRight: tile.corners[2],
              bottomLeft: tile.corners[3],
            ),
          );
        }
        if (_stopped || epoch != _version) return;
        await map.addRasterLayer(
          tile.id,
          '${tile.id}-layer',
          const RasterLayerProperties(rasterFadeDuration: 0),
          belowLayerId: 'route-line',
        );
        _visible.add(tile.id);
      }
    } catch (_) {
      stop();
      rethrow;
    } finally {
      _busy = false;
    }
    if (_pending && !_stopped) await update();
  }
}

class RouteTile {
  const RouteTile(this.z, this.x, this.y);
  final int z, x, y;
  String get id => 'tile-$z-$x-$y';
  List<LatLng> get corners => [
    corner(x, y),
    corner(x + 1, y),
    corner(x + 1, y + 1),
    corner(x, y + 1),
  ];
  LatLng corner(int x, int y) {
    final size = math.pow(2, z);
    final n = math.pi * (1 - 2 * y / size);
    return LatLng(
      math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi,
      x / size * 360 - 180,
    );
  }
}

List<RouteTile> viewportTiles(LatLngBounds bounds, int zoom) {
  final edge = (1 << zoom) - 1;
  int x(double lng) => ((lng + 180) / 360 * (1 << zoom)).floor().clamp(0, edge);
  int y(double lat) {
    final rad = lat.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    return ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) /
            2 *
            (1 << zoom))
        .floor()
        .clamp(0, edge);
  }

  final left = x(bounds.southwest.longitude),
      right = x(bounds.northeast.longitude);
  final top = y(bounds.northeast.latitude),
      bottom = y(bounds.southwest.latitude);
  final columns = left <= right ? right - left + 1 : edge - left + right + 2;
  // Return a sentinel count to select a lower zoom without allocating a huge grid.
  if (columns * (bottom - top + 1) > 16) {
    return List.generate(17, (_) => RouteTile(zoom, 0, 0));
  }
  return [
    for (var column = 0; column < columns; column++)
      for (var row = top; row <= bottom; row++)
        RouteTile(zoom, (left + column) % (edge + 1), row),
  ];
}
