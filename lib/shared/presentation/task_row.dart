import 'package:flutter/material.dart';

import 'courier_status_badge.dart';
import 'courier_surface_card.dart';

/// Compact task context shared by task, batch, and history lists.
class TaskRow extends StatelessWidget {
  const TaskRow({
    required this.reference,
    required this.leg,
    required this.status,
    required this.location,
    required this.nextStep,
    required this.onTap,
    super.key,
  });

  final String reference, leg, status, location, nextStep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return CourierSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reference, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                CourierStatusBadge(label: leg, tone: CourierStatusTone.info),
                CourierStatusBadge(label: status),
              ],
            ),
            if (location.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(location, style: textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    nextStep,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
