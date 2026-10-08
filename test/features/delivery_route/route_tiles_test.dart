import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:aisley_app/shared/route_map/route_tiles.dart';

void main() {
  test('viewport tiles preserve longitude/latitude ordering and wrap across date line', () {
    final tiles = viewportTiles(
      LatLngBounds(
        southwest: const LatLng(-1, 179),
        northeast: const LatLng(1, -179),
      ),
      2,
    );
    expect(tiles.map((t) => t.x).toSet(), {0, 3});
    expect(tiles.map((t) => t.y).toSet(), {1, 2});
    expect(tiles.length, 4);
    final corners = const RouteTile(1, 1, 0).corners;
    expect(corners[0].longitude, 0);
    // MapLibre's LatLng normalizes the eastern date line to -180.
    expect(corners[1].longitude, -180);
    expect(corners[0].latitude, closeTo(85.05112878, 0.000001));
    expect(corners[2].latitude, 0);
  });

  test(
    'wide viewport selects lower zoom without allocating an unbounded grid',
    () {
      final world = LatLngBounds(
        southwest: const LatLng(-90, -180),
        northeast: const LatLng(90, 180),
      );
      expect(viewportTiles(world, 18).length, 17);
      var zoom = 18;
      while (viewportTiles(world, zoom).length > 16 && zoom > 0) {
        zoom--;
      }
      final bounded = viewportTiles(world, zoom);
      expect(bounded.length, 16);
      expect(bounded.map((t) => t.id).toSet().length, 16);
    },
  );
}
