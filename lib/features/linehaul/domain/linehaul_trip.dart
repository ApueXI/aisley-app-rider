import '../../../core/networking/api_contract_exception.dart';

class LinehaulTrip {
  LinehaulTrip.fromJson(Object? value) {
    final j = object(value);
    id = text(j['id']);
    direction = text(j['direction']);
    status = text(j['status']);
    if (!{'outbound', 'return'}.contains(direction) ||
        !{
          'pending_acceptance',
          'scheduled',
          'rejected',
          'cancelled',
          'in_transfer',
          'receiving',
          'received',
        }.contains(status)) {
      fail();
    }
    revision = integer(j['revision'], minimum: 1);
    fromHub =
        nullableText(object(j['from_hub'])['name']) ?? 'Unknown origin hub';
    toHub =
        nullableText(object(j['to_hub'])['name']) ?? 'Unknown destination hub';
    final truck = object(j['truck']);
    truckLabel = [
      truck['plate_number'],
      truck['make'],
      truck['model'],
    ].map(nullableText).whereType<String>().join(' · ');
    parcelCount = integer(j['parcel_count']);
    final refs = j['references'];
    if (refs is! List || refs.length > parcelCount) fail();
    references = List.unmodifiable(refs.map(text));
    laneBlocked = boolean(j['lane_blocked']);
    emptyReturn = boolean(j['empty_return']);
    scheduledFor = date(j['scheduled_for']);
    releasedAt = date(j['released_for_departure_at']);
    departedAt = date(j['departed_at']);
    courierArrivedAt = date(j['courier_arrived_at']);
    arrivedAt = date(j['arrived_at']);
    unloadingClosedAt = date(j['unloading_closed_at']);
    unloadingOutcome = nullableText(j['unloading_outcome']);
    rejectionReason = nullableText(j['rejection_reason']);
    canDepart =
        boolean(j['courier_can_depart']) &&
        status == 'scheduled' &&
        releasedAt != null &&
        !laneBlocked;
    canReportArrival =
        boolean(j['courier_can_report_arrival']) &&
        status == 'in_transfer' &&
        courierArrivedAt == null;
  }
  late final String id, direction, status, fromHub, toHub, truckLabel;
  late final int revision, parcelCount;
  late final bool laneBlocked, emptyReturn, canDepart, canReportArrival;
  late final List<String> references;
  late final DateTime? scheduledFor,
      releasedAt,
      departedAt,
      courierArrivedAt,
      arrivedAt,
      unloadingClosedAt;
  late final String? unloadingOutcome, rejectionReason;

  String get statusLabel => courierArrivedAt != null && status == 'in_transfer'
      ? 'Arrival reported'
      : status.replaceAll('_', ' ');
  String get guidance => switch (status) {
    'pending_acceptance' => 'Waiting for destination Logistics approval.',
    'scheduled' when laneBlocked =>
      'A sorting lane is blocked. Contact origin Logistics.',
    'scheduled' when releasedAt == null =>
      'Waiting for origin Logistics to release the load.',
    'scheduled' =>
      'Confirm Depart only after you physically leave the origin hub.',
    'in_transfer' when courierArrivedAt == null =>
      'Report arrival when you reach the destination hub.',
    'in_transfer' => 'Arrival reported. Wait for Logistics receiving.',
    'receiving' => 'Logistics is receiving and unloading the truck.',
    'received' => 'Logistics closed unloading. Review its recorded outcome.',
    _ => 'This trip is no longer available for driver actions.',
  };
}

Never fail() => throw const ApiContractException('linehaul.response');
Map<String, dynamic> object(Object? v) =>
    v is Map<String, dynamic> ? v : fail();
String text(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : fail();
String? nullableText(Object? v) => v == null ? null : text(v);
int integer(Object? v, {int minimum = 0}) =>
    v is int && v >= minimum ? v : fail();
bool boolean(Object? v) => v is bool ? v : fail();
DateTime? date(Object? v) =>
    v == null ? null : DateTime.tryParse(text(v))?.toUtc() ?? fail();
