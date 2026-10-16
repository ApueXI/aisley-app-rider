part of '../vehicle_screen.dart';

extension _VehicleScreenDocuments on _VehicleScreenState {
  Widget _buildDocumentCard(
    BuildContext context,
    CourierVehicle vehicle,
    VehicleDocumentKind kind,
  ) {
    final controller = _vehicleController;
    final scheme = Theme.of(context).colorScheme;
    final selection = _pendingDocuments[kind];
    final preview = controller.documentPreview(kind);
    final actionStatus = controller.documentActionStatus(kind);
    final previewStatus = controller.documentPreviewStatus(kind);
    final busy = actionStatus == VehicleActionStatus.uploading;
    final currentDocument = vehicle.document(kind);
    final actionError =
        controller.documentFieldError(kind, 'file') ??
        controller.documentActionError(kind) ??
        _selectionErrors[kind];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentDocument == null
                            ? 'No current ${kind.shortLabel} is on file.'
                            : 'A private ${kind.shortLabel} is on file.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selection != null) ...[
              const SizedBox(height: 16),
              _LocalDocumentPreview(selection: selection),
              const SizedBox(height: 8),
              Text(
                '${selection.fileName} · ${_formatFileSize(selection.sizeInBytes)}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Selected image · Upload to save',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ] else if (previewStatus ==
                VehicleDocumentPreviewStatus.loading) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                label: 'Loading private ${kind.shortLabel}',
                child: const LinearProgressIndicator(),
              ),
            ] else if (previewStatus ==
                    VehicleDocumentPreviewStatus.available &&
                preview != null) ...[
              const SizedBox(height: 16),
              _PrivateDocumentPreview(bytes: preview.bytes, kind: kind),
            ],
            if (busy) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: 'Uploading ${kind.shortLabel}',
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 8),
              Text('Uploading…', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (actionError != null) ...[
              const SizedBox(height: 12),
              _VehicleBanner(message: actionError, isError: true),
            ],
            if (controller.documentPreviewError(kind) != null &&
                actionError == null) ...[
              const SizedBox(height: 12),
              _VehicleBanner(
                message: controller.documentPreviewError(kind)!,
                isError: true,
              ),
            ],
            if (controller.documentActionSuccessMessage(kind) != null) ...[
              const SizedBox(height: 12),
              _VehicleBanner(
                message: controller.documentActionSuccessMessage(kind)!,
                isError: false,
              ),
            ],
            if (!controller.canRetryRateLimit)
              const Text(
                'Please wait before loading or saving documents again.',
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (selection != null)
                  TextButton.icon(
                    onPressed: () => _openDocumentPreview(kind, selected: true),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text('View selected ${kind.shortLabel}'),
                  ),
                if (currentDocument != null && selection == null)
                  OutlinedButton.icon(
                    onPressed:
                        busy ||
                            !controller.canRetryRateLimit ||
                            previewStatus ==
                                VehicleDocumentPreviewStatus.loading
                        ? null
                        : () => _viewDocument(kind),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(
                      previewStatus == VehicleDocumentPreviewStatus.loading
                          ? 'Loading…'
                          : 'View current ${kind.shortLabel}',
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy || _isPicking[kind] == true
                      ? null
                      : () => _pickDocument(kind),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    currentDocument == null
                        ? 'Choose ${kind.shortLabel}'
                        : 'Replace ${kind.shortLabel}',
                  ),
                ),
                if (selection != null)
                  FilledButton.icon(
                    onPressed: busy || !controller.canRetryRateLimit
                        ? null
                        : () => _uploadDocument(kind),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text('Upload ${kind.shortLabel}'),
                  ),
                if (selection != null)
                  TextButton(
                    onPressed: busy ? null : () => _discardDocument(kind),
                    child: const Text('Discard'),
                  ),
                if (selection != null &&
                    (actionStatus == VehicleActionStatus.offline ||
                        actionStatus == VehicleActionStatus.timeout ||
                        actionStatus == VehicleActionStatus.failed))
                  TextButton.icon(
                    onPressed: busy || !controller.canRetryRateLimit
                        ? null
                        : () => _retryDocument(kind),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry upload'),
                  ),
                if (busy && _cancelUploads[kind] != null)
                  TextButton.icon(
                    onPressed: _cancelUploads[kind],
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel upload'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'JPEG, JPG, PNG, or WebP under 10 MB. The server validates the file before saving it.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalDocumentPreview extends StatelessWidget {
  const _LocalDocumentPreview({required this.selection});

  final VehicleDocumentSelection selection;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Local vehicle document preview',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          selection.bytes,
          width: 124,
          height: 92,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _brokenPreview(context),
        ),
      ),
    );
  }
}

class _PrivateDocumentPreview extends StatelessWidget {
  const _PrivateDocumentPreview({required this.bytes, required this.kind});

  final Uint8List bytes;
  final VehicleDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Current private ${kind.shortLabel} preview',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: 124,
          height: 92,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _brokenPreview(context),
        ),
      ),
    );
  }
}

Widget _brokenPreview(BuildContext context) {
  return Container(
    width: 124,
    height: 92,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}
