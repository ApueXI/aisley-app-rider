part of '../dashboard_screen.dart';

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.courier, this.profilePhoto});

  final CourierIdentity courier;
  final ProfilePhotoData? profilePhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final organization = courier.organizationName;
    final hub = courier.hubName;
    final affiliation = [?organization, ?hub].join(' • ');
    final photoBytes = profilePhoto?.bytes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          child: photoBytes == null || photoBytes.isEmpty
              ? Text(_initials(courier.displayName))
              : ClipOval(
                  child: Image.memory(
                    photoBytes,
                    key: const ValueKey<String>('dashboard-profile-photo'),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    semanticLabel: '${courier.displayName} profile photo',
                    errorBuilder: (context, error, stack) =>
                        Text(_initials(courier.displayName)),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courier.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text('Courier'),
              if (affiliation.isNotEmpty)
                Text(affiliation, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
