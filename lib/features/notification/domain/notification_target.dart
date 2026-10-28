import 'notification_models.dart';

enum NotificationTargetKind { pickupSchedule, finalMileTask, supportTicket }

/// A supported internal hint. The owning API must still authorize the resource.
class NotificationTarget {
  const NotificationTarget({required this.kind, required this.resourceId});

  final NotificationTargetKind kind;
  final String resourceId;

  static NotificationTarget? resolve(CourierNotification notification) {
    final id = notification.resourceId?.trim();
    final destination = notification.destination;
    if (id == null || id.isEmpty || destination == null) return null;

    if (notification.resourceType == 'support_ticket') {
      const supportedTypes = <String>{
        'support-ticket.created',
        'support-ticket.requester-replied',
        'support-ticket.admin-replied',
        'support-ticket.status-changed',
      };
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
      ).hasMatch(id);
      if (!supportedTypes.contains(notification.type) || !isUuid) return null;
      if (destination != '/support-tickets/$id') return null;
      return NotificationTarget(
        kind: NotificationTargetKind.supportTicket,
        resourceId: id,
      );
    }

    // Resource IDs are opaque single path segments, never arbitrary URLs.
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return null;
    final kind = switch (notification.resourceType) {
      'pickup_schedule' => NotificationTargetKind.pickupSchedule,
      'delivery_task' ||
      'final_mile_task' => NotificationTargetKind.finalMileTask,
      _ => null,
    };
    if (kind == null) return null;
    final path = switch (kind) {
      NotificationTargetKind.pickupSchedule => '/pickup-schedules/$id',
      NotificationTargetKind.finalMileTask => '/delivery-tasks/$id',
      NotificationTargetKind.supportTicket => '/support-tickets/$id',
    };
    if (destination != path) return null;
    return NotificationTarget(kind: kind, resourceId: id);
  }
}
