part of '../final_mile_batch_screen.dart';

class _ParcelDecisionCard extends StatelessWidget {
  const _ParcelDecisionCard({
    required this.position,
    required this.task,
    required this.batch,
    required this.controller,
  });
  final int position;
  final FinalMileBatchTask task;
  final FinalMileBatch batch;
  final FinalMileBatchController controller;

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
        _BatchParcelCard(position: position, task: task),
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
              else if (task.status == 'delivery_assigned')
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: blocked || controller.parcelRepository == null
                          ? null
                          : () => _decide(context, false),
                      child: const Text('Accept parcel'),
                    ),
                    OutlinedButton(
                      onPressed: blocked || controller.parcelRepository == null
                          ? null
                          : () => _decide(context, true),
                      child: const Text('Reject parcel'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _decide(BuildContext context, bool reject) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ParcelDecisionDialog(reject: reject),
    );
    if (reason != null && context.mounted) {
      await controller.decideParcel(
        batch.id,
        task.id,
        reason: reject ? reason : null,
      );
    }
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
    title: Text(widget.reject ? 'Reject parcel?' : 'Accept parcel?'),
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
        child: Text(widget.reject ? 'Reject parcel' : 'Accept parcel'),
      ),
    ],
  );
}
