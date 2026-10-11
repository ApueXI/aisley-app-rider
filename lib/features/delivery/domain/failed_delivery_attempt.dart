import '../../../core/networking/api_contract_exception.dart';

enum FailedDeliveryReason {
  recipientUnavailable('recipient_unavailable', 'Recipient unavailable'),
  addressUnreachable('address_unreachable', 'Address unreachable'),
  recipientRefused('recipient_refused', 'Recipient refused'),
  other('other', 'Other');

  const FailedDeliveryReason(this.value, this.label);
  final String value;
  final String label;
}

class FailedDeliveryAttempt {
  const FailedDeliveryAttempt({
    required this.id,
    required this.reason,
    required this.attemptedAt,
    this.note,
  });
  final String id;
  final String reason;
  final String? note;
  final DateTime attemptedAt;

  String get reasonLabel =>
      FailedDeliveryReason.values
          .where((item) => item.value == reason)
          .map((item) => item.label)
          .firstOrNull ??
      'Other delivery attempt';

  factory FailedDeliveryAttempt.fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final reason = data['reason'];
    final note = data['note'];
    final time = data['attempted_at'];
    if (id is! String ||
        id.trim().isEmpty ||
        reason is! String ||
        reason.trim().isEmpty ||
        (note != null && note is! String) ||
        time is! String ||
        DateTime.tryParse(time) == null) {
      throw const ApiContractException('delivery.failed_attempt');
    }
    return FailedDeliveryAttempt(
      id: id,
      reason: reason,
      note: note as String?,
      attemptedAt: DateTime.parse(time).toUtc(),
    );
  }
}

class FailedDeliveryAttemptReceipt {
  const FailedDeliveryAttemptReceipt({
    required this.taskId,
    required this.attempt,
    required this.retryAllowed,
  });
  final String taskId;
  final FailedDeliveryAttempt attempt;
  final bool retryAllowed;

  factory FailedDeliveryAttemptReceipt.fromResponse(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map ||
        data['task_id'] is! String ||
        (data['task_id'] as String).trim().isEmpty ||
        data['retry_allowed'] is! bool) {
      throw const ApiContractException('delivery.failed_attempt.receipt');
    }
    return FailedDeliveryAttemptReceipt(
      taskId: data['task_id'] as String,
      attempt: FailedDeliveryAttempt.fromJson(Map<String, dynamic>.from(data)),
      retryAllowed: data['retry_allowed'] as bool,
    );
  }
}

class PendingFailedDeliveryAttempt {
  const PendingFailedDeliveryAttempt({
    required this.reason,
    required this.note,
    required this.expectedRevision,
    required this.idempotencyKey,
  });
  final FailedDeliveryReason reason;
  final String? note;
  final int expectedRevision;
  final String idempotencyKey;
}
