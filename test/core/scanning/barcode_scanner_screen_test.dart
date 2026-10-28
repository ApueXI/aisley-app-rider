import 'package:aisley_app/core/scanning/barcode_scan_candidate.dart';
import 'package:aisley_app/core/scanning/barcode_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'fixtures/scanner_platform.dart';

void main() {
  late ScannerPlatform scanner;
  late MobileScannerPlatform original;
  setUp(() {
    original = MobileScannerPlatform.instance;
    scanner = ScannerPlatform();
    MobileScannerPlatform.instance = scanner;
  });
  tearDown(() async {
    MobileScannerPlatform.instance = original;
    await scanner.captures.close();
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(640, 320),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('square guide fits $size at $scale $brightness', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const BarcodeScannerScreen(),
            ),
          );
          await tester.pumpAndSettle();
          final guide = tester.getRect(
            find.byKey(const ValueKey('scanner-guide')),
          );
          final preview = tester.getRect(find.byType(MobileScanner));
          expect(guide.width, guide.height);
          expect(guide.width, greaterThan(0));
          expect(guide.width, lessThanOrEqualTo(preview.width * .85 + .01));
          expect(guide.height, lessThanOrEqualTo(preview.height - 32 + .01));
          if (size.height > size.width) expect(guide.height, greaterThan(150));
          expect(find.text('Use manual input'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      }
    }
  }

  testWidgets('returns one candidate and stops camera without submission', (
    tester,
  ) async {
    BarcodeScanCandidate? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<BarcodeScanCandidate>(
                  MaterialPageRoute(
                    builder: (_) => const BarcodeScannerScreen(),
                  ),
                );
              },
              child: const Text('Scan'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    scanner.captures.add(
      const BarcodeCapture(
        barcodes: [Barcode(rawValue: 'ignore', format: BarcodeFormat.ean13)],
      ),
    );
    await tester.pumpAndSettle();
    expect(result, isNull);
    scanner.captures.add(
      const BarcodeCapture(
        barcodes: [
          Barcode(rawValue: 'QR-CANDIDATE', format: BarcodeFormat.qrCode),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(result?.value, 'QR-CANDIDATE');
    expect(result?.type, BarcodeScanType.qr);
    expect(scanner.stops, greaterThan(0));
    expect(find.byType(BarcodeScannerScreen), findsNothing);
  });

  for (final error in [
    MobileScannerErrorCode.permissionDenied,
    MobileScannerErrorCode.unsupported,
    MobileScannerErrorCode.genericError,
  ]) {
    testWidgets('camera $error provides recovery without manual entry', (
      tester,
    ) async {
      scanner.startError = MobileScannerException(errorCode: error);
      await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('manual input'), findsNothing);
      expect(
        find.textContaining(
          error == MobileScannerErrorCode.permissionDenied
              ? 'settings'
              : 'Go back',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
