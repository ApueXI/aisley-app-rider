import '../../../core/networking/api_contract_exception.dart';

enum NotificationFilter {
  all('all'),
  unread('unread'),
  read('read');

  const NotificationFilter(this.apiValue);

  final String apiValue;

  String get label => switch (this) {
    NotificationFilter.all => 'All',
    NotificationFilter.unread => 'Unread',
    NotificationFilter.read => 'Read',
  };
}

class NotificationCategory {
  const NotificationCategory({required this.key, required this.label});

  final String key;
  final String label;

  factory NotificationCategory.fromJson(Map<String, dynamic> json) {
    return NotificationCategory(
      key: _requiredString(json['key'], 'notification.category.key'),
      label: _requiredString(json['label'], 'notification.category.label'),
    );
  }
}

const courierNotificationCategories = <NotificationCategory>[
  NotificationCategory(key: 'pickups', label: 'Pickups'),
  NotificationCategory(key: 'deliveries', label: 'Deliveries'),
  NotificationCategory(key: 'linehaul', label: 'Linehaul'),
  NotificationCategory(key: 'support', label: 'Support tickets'),
  NotificationCategory(key: 'other', label: 'Other'),
];

List<NotificationCategory> courierNotificationCategoryCatalog(Object? raw) {
  if (raw == null) {
    return courierNotificationCategories;
  }
  if (raw is! List) {
    throw const ApiContractException('notification.list.categories');
  }

  final knownKeys = courierNotificationCategories
      .map((item) => item.key)
      .toSet();
  final labels = <String, String>{};
  for (final value in raw) {
    if (value is! Map) {
      throw const ApiContractException('notification.list.category');
    }
    final category = NotificationCategory.fromJson(
      Map<String, dynamic>.from(value),
    );
    if (knownKeys.contains(category.key) && category.key != 'other') {
      labels[category.key] = category.label;
    }
  }

  return List<NotificationCategory>.unmodifiable(
    courierNotificationCategories.map(
      (category) => category.key == 'other'
          ? category
          : NotificationCategory(
              key: category.key,
              label: labels[category.key] ?? category.label,
            ),
    ),
  );
}

class CourierNotification {
  const CourierNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.resourceType,
    required this.createdAt,
    this.readAt,
    this.resourceId,
    this.destination,
    this.category = 'other',
    this.categoryLabel = 'Other',
  });

  final String id;
  final String type;
  final String title;
  final String summary;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? resourceType;
  final String? resourceId;
  final String? destination;
  final String category;
  final String categoryLabel;

  bool get isRead => readAt != null;

  bool get hasDestination => destination != null && destination!.isNotEmpty;

  String get typeLabel => switch (type) {
    'pickup-schedule.assigned' => 'Pickup assigned',
    'pickup-schedule.revised' => 'Pickup updated',
    'pickup-schedule.cancelled' => 'Pickup cancelled',
    'pickup-schedule.reminder' => 'Pickup reminder',
    'courier-task.final-mile-offered' => 'Delivery offered',
    'support-ticket.created' => 'Support ticket received',
    'support-ticket.requester-replied' => 'Support ticket reply',
    'support-ticket.admin-replied' => 'Support reply received',
    'support-ticket.status-changed' => 'Support ticket updated',
    _ => 'Courier update',
  };

  CourierNotification copyWith({DateTime? readAt}) {
    return CourierNotification(
      id: id,
      type: type,
      title: title,
      summary: summary,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      resourceType: resourceType,
      resourceId: resourceId,
      destination: destination,
      category: category,
      categoryLabel: categoryLabel,
    );
  }

  factory CourierNotification.fromJson(Map<String, dynamic> json) {
    final categoryValue = _nullableString(
      json['category'],
      'notification.category',
    );
    final category =
        courierNotificationCategories.any((value) => value.key == categoryValue)
        ? categoryValue!
        : 'other';
    final categoryLabelValue = _nullableString(
      json['category_label'],
      'notification.category_label',
    );
    return CourierNotification(
      id: _requiredString(json['id'], 'notification.id'),
      type: _requiredString(json['type'], 'notification.type'),
      title: _requiredString(json['title'], 'notification.title'),
      summary: _requiredString(json['summary'], 'notification.summary'),
      readAt: _nullableDateTime(json['read_at'], 'notification.read_at'),
      createdAt: _requiredDateTime(
        json['created_at'],
        'notification.created_at',
      ),
      resourceType: _nullableString(
        json['resource_type'],
        'notification.resource_type',
      ),
      resourceId: _nullableString(
        json['resource_id'],
        'notification.resource_id',
      ),
      destination: _nullableString(
        json['destination'],
        'notification.destination',
      ),
      category: category,
      categoryLabel: category == 'other'
          ? 'Other'
          : categoryLabelValue ??
                courierNotificationCategories
                    .firstWhere((value) => value.key == category)
                    .label,
    );
  }
}

class CourierNotificationPage {
  const CourierNotificationPage({
    required this.items,
    this.nextCursor,
    this.generatedAt,
    this.categories = courierNotificationCategories,
  });

  final List<CourierNotification> items;
  final String? nextCursor;
  final DateTime? generatedAt;
  final List<NotificationCategory> categories;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value.trim();
}

String? _nullableString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiContractException(field);
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDateTime(Object? value, String field) {
  if (value is! String) {
    throw ApiContractException(field);
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw ApiContractException(field);
  }
  return parsed.toUtc();
}

DateTime? _nullableDateTime(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return _requiredDateTime(value, field);
}
