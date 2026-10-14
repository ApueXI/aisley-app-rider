import 'package:flutter/material.dart';

/// Compact presentation shared by task lists; callers own eligibility.
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
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        title: Text(reference, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$leg · $status'),
              const SizedBox(height: 4),
              Text(location),
              const SizedBox(height: 4),
              Text(nextStep, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
      const Divider(height: 1),
    ],
  );
}
