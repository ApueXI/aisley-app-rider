import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/security/courier_map_security.dart';
import '../../core/networking/api_client.dart';
import 'route_map_data.dart';
import 'route_map_scope.dart';
import 'route_marker_image.dart';
import 'route_tiles.dart';

class RouteMapView extends StatefulWidget {
  const RouteMapView({required this.data, required this.onFailure, super.key});
  final RouteMapData data;
  final void Function(ApiException? error) onFailure;
  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  MapLibreMapController? _map;
  CourierMapSecurity? _security;
  RouteTiles? _tiles;
  Timer? _startupTimer;
  bool _failed = false;
  bool _ready = false;
  bool _initializing = false;
  int _generation = 0;
  int _mapVersion = 0;

  @override
  void didUpdateWidget(RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.data.line, widget.data.line) ||
        !listEquals(oldWidget.data.markers, widget.data.markers) ||
        oldWidget.data.geometrySource != widget.data.geometrySource) {
      _generation++;
      _mapVersion++;
      _tiles?.stop();
      _tiles = null;
      _map = null;
      _ready = false;
      _failed = false;
      _initializing = false;
      _startupTimer?.cancel();
      if ((kIsWeb || defaultTargetPlatform == TargetPlatform.android) &&
          RouteMapScope.maybeOf(context)?.renderer == null &&
          _security != null &&
          widget.data.positions.isNotEmpty) {
        _startupTimer = Timer(const Duration(seconds: 25), _fail);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final security = RouteMapScope.maybeOf(context)?.security;
    if (security != _security) {
      _security?.removeListener(_sessionEnded);
      _security = security;
      _security?.addListener(_sessionEnded);
    }
    if (_startupTimer == null &&
        security != null &&
        RouteMapScope.maybeOf(context)?.renderer == null &&
        (kIsWeb || defaultTargetPlatform == TargetPlatform.android) &&
        widget.data.positions.isNotEmpty) {
      _startupTimer = Timer(const Duration(seconds: 25), _fail);
    }
  }

  void _sessionEnded() {
    _generation++;
    _tiles?.stop();
    _startupTimer?.cancel();
    if (mounted) {
      setState(() {
        _failed = true;
        _ready = false;
      });
    }
  }

  void _fail([Object? error]) {
    if (!mounted || _failed) return;
    _tiles?.stop();
    _startupTimer?.cancel();
    _generation++;
    setState(() {
      _failed = true;
      _ready = false;
    });
    widget.onFailure(error is ApiException ? error : null);
  }

  @override
  void dispose() {
    _generation++;
    _security?.removeListener(_sessionEnded);
    _tiles?.stop();
    _startupTimer?.cancel();
    // Removing the platform view releases all per-map sources and image bytes.
    // No SDK headers were installed, so no global credentials need clearing.
    super.dispose();
  }

  Future<void> _styleLoaded() async {
    final map = _map, security = _security;
    if (map == null || security == null || _failed || _ready || _initializing) {
      return;
    }
    _initializing = true;
    final epoch = _generation;
    try {
      final scheme = Theme.of(context).colorScheme;
      await map.symbolManager!.setIconAllowOverlap(true);
      await map.symbolManager!.setIconIgnorePlacement(true);
      if (!mounted || epoch != _generation) return;
      await map.addGeoJsonSource(
        'route',
        widget.data.line.isEmpty
            ? {'type': 'FeatureCollection', 'features': <Object>[]}
            : {
                'type': 'Feature',
                'properties': <String, Object?>{},
                'geometry': {
                  'type': 'LineString',
                  'coordinates': widget.data.line
                      .map((p) => [p.longitude, p.latitude])
                      .toList(),
                },
              },
      );
      if (!mounted || epoch != _generation) return;
      await map.addLineLayer(
        'route',
        'route-line',
        LineLayerProperties(lineColor: _hex(scheme.primary), lineWidth: 5),
        // Raster images are inserted below the route; symbols stay above both.
        belowLayerId: map.symbolManager!.layerIds.first,
      );
      if (!mounted || epoch != _generation) return;
      for (var i = 0; i < widget.data.markers.length; i++) {
        final marker = widget.data.markers[i];
        final id = 'marker-$i';
        final bytes = await routeMarkerImage(
          marker.isHub ? 'H' : marker.label,
          marker.isHub ? scheme.secondary : scheme.primary,
          marker.isHub ? scheme.onSecondary : scheme.onPrimary,
        );
        if (!mounted || epoch != _generation) return;
        await map.addImage(id, bytes);
        if (!mounted || epoch != _generation) return;
        await map.addSymbol(
          SymbolOptions(
            geometry: LatLng(
              marker.position.latitude,
              marker.position.longitude,
            ),
            iconImage: id,
            iconSize: 0.6,
          ),
        );
        if (!mounted || epoch != _generation) return;
      }
      await _fit();
      final maxZoom = await security.loadStyle();
      if (!mounted || epoch != _generation) return;
      _tiles = RouteTiles(security, map)..maxZoom = maxZoom;
      await _tiles!.update();
      if (!mounted || epoch != _generation) return;
      _startupTimer?.cancel();
      setState(() => _ready = true);
    } on MapSessionEnded {
      _sessionEnded();
    } catch (error) {
      if (epoch == _generation) _fail(error);
    } finally {
      if (epoch == _generation) _initializing = false;
    }
  }

  Future<void> _updateTiles() async {
    if (!_ready || _failed) return;
    final epoch = _generation;
    try {
      await _tiles?.update();
    } catch (error) {
      if (epoch == _generation) _fail(error);
    }
  }

  Future<void> _fit() async {
    final map = _map, points = widget.data.positions;
    final epoch = _generation;
    if (map == null || points.isEmpty) return;
    try {
      final minLat = points.map((p) => p.latitude).reduce(math.min),
          maxLat = points.map((p) => p.latitude).reduce(math.max);
      final minLng = points.map((p) => p.longitude).reduce(math.min),
          maxLng = points.map((p) => p.longitude).reduce(math.max);
      if (minLat == maxLat && minLng == maxLng) {
        await map.moveCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 13),
        );
      } else {
        await map.moveCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            left: 40,
            top: 40,
            right: 40,
            bottom: 40,
          ),
        );
      }
    } catch (_) {
      if (epoch == _generation) _fail();
    }
  }

  Future<void> _zoom(double amount) async {
    final map = _map;
    final epoch = _generation;
    if (map == null) return;
    try {
      await map.moveCamera(CameraUpdate.zoomBy(amount));
    } catch (_) {
      if (epoch == _generation) _fail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = RouteMapScope.maybeOf(context);
    final injected = scope?.renderer;
    if (injected != null) {
      return injected(context, widget.data, () => widget.onFailure(null));
    }
    final supported = kIsWeb || defaultTargetPlatform == TargetPlatform.android;
    if (!supported ||
        scope == null ||
        _failed ||
        widget.data.positions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          _failed
              ? 'Map could not be loaded. Route stops remain available below.'
              : 'Map unavailable. Route stops remain available below.',
        ),
      );
    }
    final first = widget.data.positions.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.data.isFallback
              ? 'Straight-line fallback — roads and travel conditions may differ.'
              : widget.data.line.isEmpty
              ? 'Route line unavailable. Showing known locations.'
              : 'Road route — distance and travel time are advisory.',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: Semantics(
            label: 'Route map. H marks the Logistics hub. Numbered stops are listed below.',
            child: MapLibreMap(
              key: ValueKey(_mapVersion),
              annotationOrder: const [AnnotationType.symbol],
              dragEnabled: false,
              styleString: CourierMapSecurity.emptyStyle,
              initialCameraPosition: CameraPosition(
                target: LatLng(first.latitude, first.longitude),
                zoom: 10,
              ),
              trackCameraPosition: true,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              onMapCreated: (controller) {
                _map = controller;
              },
              onStyleLoadedCallback: () => unawaited(_styleLoaded()),
              onCameraIdle: () => unawaited(_updateTiles()),
            ),
          ),
        ),
        if (!_ready)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Loading map…'),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _ready ? _fit : null,
              icon: const Icon(Icons.fit_screen),
              label: const Text('Fit route'),
            ),
            IconButton(
              onPressed: _ready ? () => _zoom(1) : null,
              tooltip: 'Zoom in',
              icon: const Icon(Icons.add),
            ),
            IconButton(
              onPressed: _ready ? () => _zoom(-1) : null,
              tooltip: 'Zoom out',
              icon: const Icon(Icons.remove),
            ),
          ],
        ),
        const Text('H: Logistics hub • Numbers: stop order'),
        const Text('© Geoapify • OpenStreetMap contributors • OpenMapTiles'),
      ],
    );
  }
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2)}';
