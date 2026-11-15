part of '../final_mile_batch_screen.dart';

class _OfferedTaskActions extends StatelessWidget {
  const _OfferedTaskActions({
    required this.task,
    required this.controller,
    required this.scheduleId,
    required this.authController,
    required this.enabled,
    required this.pending,
    required this.onDecisionComplete,
    this.chatController,
  });

  final FinalMileBatchTask task;
  final FinalMileBatchController controller;
  final String scheduleId;
  final AuthController authController;
  final ChatController? chatController;
  final bool enabled;
  final bool pending;
  final Future<void> Function() onDecisionComplete;

  @override
  Widget build(BuildContext context) {
    final blocked = !enabled || controller.parcelRepository == null;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: pending
                    ? blocked
                          ? null
                          : () => _retry(context)
                    : blocked
                    ? null
                    : () => _accept(context),
                child: Text(
                  pending ? 'Retry same decision' : 'Accept delivery',
                ),
              ),
            ),
            if (!pending || chatController != null) ...[
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final reject = OutlinedButton(
                    onPressed: blocked || pending
                        ? null
                        : () => _reject(context),
                    child: const Text('Reject offer'),
                  );
                  final message = chatController == null
                      ? null
                      : OutlinedButton.icon(
                          onPressed: () => _messageLogistics(context),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Message Logistics'),
                        );
                  if (constraints.maxWidth < 380 || message == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        reject,
                        if (message != null) ...[
                          const SizedBox(height: 8),
                          message,
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: reject),
                      const SizedBox(width: 8),
                      Expanded(child: message),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => const _ParcelDecisionDialog(reject: false),
    );
    if (confirmed == null || !context.mounted) return;
    if (await controller.decideParcel(scheduleId, task.id) && context.mounted) {
      await onDecisionComplete();
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ParcelDecisionDialog(reject: true),
    );
    if (reason == null || !context.mounted) return;
    if (await controller.decideParcel(scheduleId, task.id, reason: reason) &&
        context.mounted) {
      await onDecisionComplete();
    }
  }

  Future<void> _retry(BuildContext context) async {
    if (await controller.retryParcelDecision(scheduleId, task.id) &&
        context.mounted) {
      await onDecisionComplete();
    }
  }

  Future<void> _messageLogistics(BuildContext context) async {
    final chat = chatController;
    if (chat == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          controller: chat,
          authController: authController,
          task: ChatTaskContext(
            leg: 'final_mile',
            taskId: task.id,
            counterpartyRole: 'logistics',
            reference: task.orderReference,
          ),
        ),
      ),
    );
  }
}

String _taskStateMessage(String status) => switch (status) {
  'delivery_accepted' => 'This delivery is accepted. Open Delivery work to submit photo proof and the Delivered intent.',
  'picked_up_from_hub' || 'in_transit' || 'out_for_delivery' => 'This delivery is in progress. Open Delivery work to review the current step.',
  'delivered' => 'The server confirms this delivery is complete.',
  'rejected' ||
  'cancelled' => 'This offer is no longer available for Courier action.',
  _ => 'No delivery action is available for the current server state.',
};
