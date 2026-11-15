part of '../policy_screen.dart';

extension _PolicyCurrentCard on _PolicyScreenState {
  Widget _buildPolicyCard(BuildContext context, PolicyConsentItem item) {
    final type = item.type!;
    final document = controller.documentFor(type);
    final stale =
        controller.isDocumentStale(type) ||
        document?.version.version != item.currentVersion;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              type == PolicyType.termsOfService
                  ? Icons.gavel_outlined
                  : Icons.shield_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  item.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (document == null)
          Text(
            item.currentVersion == null
                ? 'No published version is currently available.'
                : 'This document could not be loaded. Refresh before accepting.',
          )
        else ...[
          Text(
            'Version ${document.version.version} · Published ${_formatDate(context, document.version.publishedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (stale)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'This document may be stale. Refresh before accepting.',
              ),
            ),
          if (document.version.changeSummary != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('What changed: ${document.version.changeSummary!}'),
            ),
          const SizedBox(height: 16),
          SelectableText(
            document.version.content,
            minLines: 3,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => _openHistory(type),
            child: const Text('View published history'),
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedConfirmation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your confirmation',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final type in PolicyType.values)
          Builder(
            builder: (context) {
              final item = controller.consentFor(type);
              final covered =
                  item?.currentVersion != null && item?.required == false;
              final available =
                  item?.required == true &&
                  controller.documentFor(type)?.version.version ==
                      item?.currentVersion &&
                  !controller.isDocumentStale(type);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value:
                    covered ||
                    (available &&
                        _confirmedVersions[type] == item?.currentVersion),
                title: Text(
                  covered
                      ? '${type.fallbackLabel}: no further confirmation needed.'
                      : 'I have read and agree to the ${type.fallbackLabel}${item?.currentVersion == null ? '' : ', version ${item!.currentVersion}'}.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: covered
                    ? Text(
                        item?.accepted == true
                            ? 'Accepted${item?.acceptedAt == null ? '.' : ' ${_formatDate(context, item!.acceptedAt)}.'}'
                            : 'No renewed acceptance is required.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                onChanged: controller.isBusy || !available
                    ? null
                    : (value) => _updateConfirmation(() {
                        if (value == true) {
                          _confirmedVersions[type] = item!.currentVersion!;
                        } else {
                          _confirmedVersions.remove(type);
                        }
                      }),
              );
            },
          ),
        if (controller.consentStatus!.allRequiredAccepted)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Your policy consent is up to date.'),
          ),
      ],
    );
  }

  Widget? _buildBottomActions(BuildContext context) {
    final pending =
        controller.consentStatus?.supportedPolicies.any(
          (item) => item.required,
        ) ??
        false;
    if (!pending && !widget.showSignOutAction) return null;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pending)
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _canAcceptTogether() ? _acceptTogether : null,
                    child: Text(
                      controller.state == PolicyViewState.accepting
                          ? 'Accepting…'
                          : 'Accept',
                    ),
                  ),
                ),
              if (widget.showSignOutAction) ...[
                if (pending) const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: widget.authController.isSigningOut
                        ? null
                        : _signOut,
                    icon: widget.authController.isSigningOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _canAcceptTogether() {
    final pending =
        controller.consentStatus?.supportedPolicies
            .where((item) => item.required)
            .toList() ??
        const <PolicyConsentItem>[];
    return pending.isNotEmpty &&
        !controller.isBusy &&
        !controller.hasUnsupportedRequiredPolicy &&
        (controller.state != PolicyViewState.rateLimited ||
            controller.canRetryRateLimit) &&
        pending.every(
          (item) =>
              item.currentVersion != null &&
              _confirmedVersions[item.type] == item.currentVersion &&
              controller.documentFor(item.type!)?.version.version ==
                  item.currentVersion &&
              !controller.isDocumentStale(item.type!),
        );
  }
}
