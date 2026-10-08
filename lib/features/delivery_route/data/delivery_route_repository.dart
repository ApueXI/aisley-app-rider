import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/delivery_route_models.dart';

abstract interface class DeliveryRouteRepository {
  Future<DeliveryRoute> fetchRoute(String scheduleId);
}

class ApiDeliveryRouteRepository implements DeliveryRouteRepository {
  ApiDeliveryRouteRepository({required this.client});
  final ApiClient client;
  @override
  Future<DeliveryRoute> fetchRoute(String scheduleId) async {
    if (scheduleId.trim().isEmpty) {
      throw const ApiContractException('route.schedule');
    }
    final response = await client.get(
      '/courier/final-mile-batches/${Uri.encodeComponent(scheduleId.trim())}/route',
      authenticated: true,
      headers: const {'Cache-Control': 'no-store'},
    );
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) return DeliveryRoute.fromResponse(json);
    } on FormatException {
      /* Report a stable contract failure. */
    }
    throw const ApiContractException('route.response');
  }
}
