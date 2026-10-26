import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../domain/linehaul_trip.dart';
import '../domain/linehaul_route.dart';

abstract interface class LinehaulRepository {
  Future<List<LinehaulTrip>> trips();
  Future<LinehaulRoute> route(String id);
  Future<LinehaulTrip> confirm(String id, String action, int revision);
}

class ApiLinehaulRepository implements LinehaulRepository {
  ApiLinehaulRepository(this.client);
  final ApiClient client;
  static const base = '/courier/linehaul-trips';
  Object? data(String body) {
    try {
      return object(jsonDecode(body))['data'];
    } on FormatException {
      return fail();
    }
  }

  @override
  Future<List<LinehaulTrip>> trips() async {
    final value = data(
      (await client.get(
        base,
        authenticated: true,
        followRedirects: false,
      )).body,
    );
    if (value is! List || value.length > 50) fail();
    final trips = value.map(LinehaulTrip.fromJson).toList();
    if (trips.map((t) => t.id).toSet().length != trips.length) fail();
    return List.unmodifiable(trips);
  }

  @override
  Future<LinehaulRoute> route(String id) async => LinehaulRoute.fromJson(
    data(
      (await client.get(
        '$base/${Uri.encodeComponent(id)}/route',
        authenticated: true,
        followRedirects: false,
      )).body,
    ),
  );
  @override
  Future<LinehaulTrip> confirm(String id, String action, int revision) async {
    if (!{'depart', 'arrival'}.contains(action) || revision < 1) fail();
    final trip = LinehaulTrip.fromJson(
      data(
        (await client.postJson(
          '$base/${Uri.encodeComponent(id)}/$action',
          authenticated: true,
          body: {'expected_revision': revision, 'confirmation': true},
        )).body,
      ),
    );
    if (trip.id != id) fail();
    return trip;
  }
}
