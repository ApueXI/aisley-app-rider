import 'package:flutter/material.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../pickup/domain/pickup_models.dart';
import '../controllers/delivery_controller.dart';
import 'failed_delivery_attempt_form.dart';

class FailedDeliveryAttemptCard extends StatelessWidget {
  const FailedDeliveryAttemptCard({
    required this.task,
    required this.controller,
    required this.authController,
    super.key,
  });
  final PickupTask task;
  final DeliveryController controller;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final receipt = controller.failedAttemptReceipts[task.id];
    final attempts = controller.contexts[task.id]?.failedAttempts ?? const [];
    final count = controller.contexts[task.id]?.failedAttemptCount;
    final pending = controller.hasPendingFailedAttempt(task);
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unsuccessful delivery',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Report an unsuccessful visit. The parcel stays with you and delivery remains open.',
            ),
            if (receipt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Failed attempt recorded. Use a fresh photo for the next delivery.',
                  ),
                ),
              ),
            if (count != null && count > 0) ...[
              const SizedBox(height: 12),
              Text('Recorded attempts: $count'),
              if (count > attempts.length)
                const Text('Showing the latest attempts.'),
              for (final attempt in attempts)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${attempt.reasonLabel} • ${_time(context, attempt.attemptedAt)}'
                    '${attempt.note == null ? '' : '\n${attempt.note}'}',
                  ),
                ),
            ],
            if (controller.failedAttemptErrors[task.id] != null && !pending)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  controller.failedAttemptErrors[task.id]!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  authController.status != AuthStatus.authenticated ||
                      controller.isReportingFailedAttempt(task) ||
                      (!pending && !controller.canReportFailedAttempt(task))
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FailedDeliveryAttemptForm(
                          task: task,
                          controller: controller,
                          authController: authController,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.report_outlined),
              label: Text(
                pending ? 'Review unconfirmed report' : 'Report failed attempt',
              ),
            ),
            if (controller.isCompletionPending(task))
              const Text(
                'Reporting is unavailable while Logistics reviews this delivery.',
              ),
          ],
        ),
      ),
    );
  }
}

String _time(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatMediumDate(local)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
