part of '../final_mile_batch_screen.dart';

class _ParcelDecisionCard extends StatelessWidget {
  const _ParcelDecisionCard({
    required this.task,
    required this.batch,
    required this.controller,
    required this.onOpenParcel,
  });
  final FinalMileBatchTask task;
  final FinalMileBatch batch;
  final FinalMileBatchController controller;
  final VoidCallback onOpenParcel;

  @override
  Widget build(BuildContext context) {
    final pending = controller.hasPendingDecision(task.id);
    final blocked =
        controller.decidingTask != null ||
        !controller.canRetryRateLimit ||
        controller.hasUncertainDecision;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BatchParcelCard(task: task),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.parcelErrors[task.id] case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (pending)
                TextButton(
                  onPressed:
                      controller.decidingTask != null ||
                          !controller.canRetryRateLimit
                      ? null
                      : () => controller.retryParcelDecision(batch.id, task.id),
                  child: const Text('Retry same decision'),
                )
              else
                OutlinedButton.icon(
                  onPressed: blocked ? null : onOpenParcel,
                  icon: Icon(
                    task.status == 'delivery_assigned'
                        ? Icons.rate_review_outlined
                        : Icons.open_in_new,
                  ),
                  label: Text(
                    task.status == 'delivery_assigned'
                        ? 'Review parcel'
                        : 'View parcel details',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParcelDecisionDialog extends StatefulWidget {
  const _ParcelDecisionDialog({required this.reject});
  final bool reject;
  @override
  State<_ParcelDecisionDialog> createState() => _ParcelDecisionDialogState();
}

class _ParcelDecisionDialogState extends State<_ParcelDecisionDialog> {
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.reject ? 'Reject offer?' : 'Accept delivery?'),
    content: widget.reject
        ? TextField(
            controller: reason,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              helperText: '3–1,000 characters',
            ),
          )
        : const Text(
            'Accept responsibility for this parcel. Other parcels keep their current decisions.',
          ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: widget.reject && reason.text.trim().runes.length < 3
            ? null
            : () => Navigator.pop(context, reason.text),
        child: Text(widget.reject ? 'Reject offer' : 'Accept delivery'),
      ),
    ],
  );
}
