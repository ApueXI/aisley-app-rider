import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'barcode_scan_candidate.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({this.title = 'Scan parcel code', super.key});

  final String title;

  static bool get isSupported {
    return kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: <BarcodeFormat>[BarcodeFormat.qrCode, BarcodeFormat.code128],
  );

  bool _didCapture = false;
  bool _showDecodeError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      MobileScannerPlatform.instance.setWebBarcodeReader(
        WebBarcodeReader.zxingWasm,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!BarcodeScannerScreen.isSupported || _didCapture) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_controller.value.isRunning &&
            !_controller.value.isStarting &&
            _controller.value.hasCameraPermission) {
          unawaited(_controller.start());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!BarcodeScannerScreen.isSupported) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _UnsupportedScannerMessage(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Live camera preview for QR and Code 128 tracking ID',
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        onDetectError: _onDetectError,
                        errorBuilder: _buildScannerError,
                        placeholderBuilder: (context) => const ColoredBox(
                          color: Colors.black,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      IgnorePointer(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final side = math.max(
                              0.0,
                              math.min(
                                constraints.maxWidth * .85,
                                constraints.maxHeight - 32,
                              ),
                            );
                            return Center(
                              child: Container(
                                key: const ValueKey('scanner-guide'),
                                width: side,
                                height: side,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_showDecodeError)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: Colors.black87,
                            child: const Text(
                              'The camera could not read that frame. Keep the code steady and try again.',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .35,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      children: [
                        const Text(
                          'Scan a parcel QR code or Code 128 tracking ID. Review the captured value before confirming pickup.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didCapture) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final candidate = BarcodeScanCandidate.fromBarcode(barcode);
      if (candidate == null) {
        continue;
      }
      _didCapture = true;
      unawaited(_returnCandidate(candidate));
      return;
    }
  }

  Future<void> _returnCandidate(BarcodeScanCandidate candidate) async {
    try {
      await _controller.stop();
    } finally {
      if (mounted) {
        Navigator.of(context).pop(candidate);
      }
    }
  }

  void _onDetectError(Object error, StackTrace stackTrace) {
    if (!mounted || _showDecodeError) {
      return;
    }
    setState(() {
      _showDecodeError = true;
    });
  }

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => 'Camera permission was denied. Allow camera access in settings, then reopen the scanner.',
      MobileScannerErrorCode.unsupported => 'Camera scanning is unavailable on this device. Go back and use a supported device.',
      _ =>
        'The camera could not start. Go back and reopen the scanner to retry.',
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _UnsupportedScannerMessage extends StatelessWidget {
  const _UnsupportedScannerMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.no_photography_outlined, size: 48),
        const SizedBox(height: 16),
        Text(
          'Camera scanning is not available on this platform.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text('Use the Android app or a supported browser to scan.'),
      ],
    );
  }
}
