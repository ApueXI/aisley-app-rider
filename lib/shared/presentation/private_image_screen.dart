import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays authorized bytes from the owner's memory without another read.
class PrivateImageScreen extends StatefulWidget {
  const PrivateImageScreen({
    required this.title,
    required this.changes,
    required this.isAuthorized,
    required this.readBytes,
    super.key,
  });

  final String title;
  final Listenable changes;
  final bool Function() isAuthorized;
  final Uint8List? Function() readBytes;

  @override
  State<PrivateImageScreen> createState() => _PrivateImageScreenState();
}

class _PrivateImageScreenState extends State<PrivateImageScreen> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      4.0,
    );
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.changes,
    builder: (context, _) {
      final bytes = widget.isAuthorized() ? widget.readBytes() : null;
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Close preview',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
              title: Text(widget.title),
            ),
            body: bytes == null
                ? const Center(
                    child: Text('This image is no longer available.'),
                  )
                : SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                InteractiveViewer(
                                  transformationController: _transform,
                                  minScale: 1,
                                  maxScale: 4,
                                  child: Image.memory(
                                    bytes,
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    fit: BoxFit.contain,
                                    semanticLabel: widget.title,
                                    errorBuilder: (context, error, stack) =>
                                        const Center(
                                          child: Text(
                                            'The image could not be displayed. Close and choose or load it again.',
                                          ),
                                        ),
                                  ),
                                ),
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Zoom out',
                              onPressed: () => _zoom(0.8),
                              icon: const Icon(Icons.remove),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _transform.value = Matrix4.identity(),
                              child: const Text('Fit image'),
                            ),
                            IconButton(
                              tooltip: 'Zoom in',
                              onPressed: () => _zoom(1.25),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
