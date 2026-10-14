part of '../policy_screen.dart';

extension _PolicyCurrentCard on _PolicyScreenState {
  Widget _buildPolicyCard(BuildContext context, PolicyConsentItem item) {
    final type = item.type!;
    final document = controller.documentFor(type);
    final version = item.currentVersion;
    final documentIsStale =
        document != null &&
        (controller.isDocumentStale(type) ||
            document.version.version != version);
    final isConfirmed = version != null && _confirmedVersions[type] == version;
    final isAccepted = item.accepted && item.acceptedVersion == version;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.policy_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (version == null)
              Text(
                'No published version is currently available.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else if (document == null)
              Text(
                'The current version could not be loaded. Refresh to try again.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else ...[
              if (documentIsStale) ...[
                const _PolicyBanner(
                  message: 'This displayed policy may be stale. Refresh before accepting it.',
                  isError: true,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Version ${document.version.version} • ${_formatDate(context, document.version.publishedAt)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (document.version.changeSummary != null) ...[
                const SizedBox(height: 10),
                Text(
                  document.version.changeSummary!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              SelectableText(
                document.version.content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (isAccepted)
                _AcceptedPolicyLabel(item: item, version: version)
              else if (item.required && !documentIsStale) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isConfirmed,
                  onChanged: controller.state == PolicyViewState.accepting
                      ? null
                      : (checked) {
                          _updateConfirmation(() {
                            if (checked == true) {
                              _confirmedVersions[type] = version;
                            } else {
                              _confirmedVersions.remove(type);
                            }
                          });
                        },
                  title: Text(
                    'I have read and agree to the current ${item.label}, version $version.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: !isConfirmed || controller.isBusy
                      ? null
                      : () => _accept(type),
                  child: Text(
                    controller.state == PolicyViewState.accepting
                        ? 'Saving…'
                        : 'Accept ${item.label}',
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openHistory(type),
                icon: const Icon(Icons.history),
                label: const Text('View published history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
