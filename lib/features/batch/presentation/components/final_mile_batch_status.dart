part of '../final_mile_batch_screen.dart';

class _BatchStatusChip extends StatelessWidget {
  const _BatchStatusChip({required this.status});

  final FinalMileBatchStatus status;

  @override
  Widget build(BuildContext context) {
    return CourierStatusBadge(
      label: _batchStatusLabel(status),
      tone: switch (status) {
        FinalMileBatchStatus.accepted => CourierStatusTone.success,
        FinalMileBatchStatus.inProgress => CourierStatusTone.info,
        FinalMileBatchStatus.offered => CourierStatusTone.neutral,
      },
    );
  }
}

class _BatchScrollableState extends StatelessWidget {
  const _BatchScrollableState({required this.child, this.semanticsLabel});

  final Widget child;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height * .55,
          ),
          child: Center(
            child: Semantics(
              liveRegion: semanticsLabel != null,
              label: semanticsLabel,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _BatchErrorState extends StatelessWidget {
  const _BatchErrorState({
    required this.message,
    required this.status,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.canOpenPolicies,
  });

  final String message;
  final FinalMileBatchLoadStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool canOpenPolicies;

  @override
  Widget build(BuildContext context) {
    return _BatchScrollableState(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (_canRetryBatchLoad(status))
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              if (status == FinalMileBatchLoadStatus.consentRequired &&
                  canOpenPolicies)
                FilledButton.icon(
                  onPressed: onOpenPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchInlineError extends StatelessWidget {
  const _BatchInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

bool _isBatchBlocking(FinalMileBatchLoadStatus status) {
  return status != FinalMileBatchLoadStatus.idle &&
      status != FinalMileBatchLoadStatus.loading &&
      status != FinalMileBatchLoadStatus.loaded &&
      status != FinalMileBatchLoadStatus.empty;
}

bool _canRetryBatchLoad(FinalMileBatchLoadStatus status) {
  return status == FinalMileBatchLoadStatus.offline ||
      status == FinalMileBatchLoadStatus.timeout ||
      status == FinalMileBatchLoadStatus.rateLimited ||
      status == FinalMileBatchLoadStatus.failed;
}
