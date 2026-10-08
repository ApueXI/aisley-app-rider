import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_camera_platform.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_camera_screen.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture_result.dart';

import 'fixtures/delivery_photo_camera_screen_fixture.dart';

void main() {
  testWidgets('captures a still photo from the rear-camera session', (
    tester,
  ) async {
    final session = FakeCameraSession();
    DeliveryPhotoCaptureResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<DeliveryPhotoCaptureResult>(
                  builder: (_) => DeliveryPhotoCameraScreen(
                    platform: FakeCameraPlatform(session: session),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Rear camera preview for photo proof'),
      findsOneWidget,
    );

    await tester.tap(find.text('Take POD photo'));
    await tester.pumpAndSettle();

    expect(result?.status, DeliveryPhotoCaptureStatus.captured);
    expect(result?.file?.name, 'captured.jpg');
    expect(session.takePictureCalls, 1);
    expect(session.disposed, isTrue);
  });

  testWidgets('offers retry and file fallback when permission is denied', (
    tester,
  ) async {
    DeliveryPhotoCaptureResult? result;
    final platform = FakeCameraPlatform(
      failure: const DeliveryPhotoCameraFailure(
        DeliveryPhotoCameraFailureKind.permissionDenied,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<DeliveryPhotoCaptureResult>(
                  builder: (_) => DeliveryPhotoCameraScreen(platform: platform),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission was denied'), findsOneWidget);
    expect(find.text('Retry camera'), findsOneWidget);
    expect(find.text('Use file chooser instead'), findsOneWidget);

    await tester.tap(find.text('Retry camera'));
    await tester.pumpAndSettle();
    expect(platform.openCalls, 2);

    await tester.tap(find.text('Use file chooser instead'));
    await tester.pumpAndSettle();
    expect(result?.status, DeliveryPhotoCaptureStatus.chooseFile);
  });

  testWidgets('keeps capture failure recoverable without leaving camera', (
    tester,
  ) async {
    final session = FakeCameraSession(
      takeFailure: const DeliveryPhotoCameraFailure(
        DeliveryPhotoCameraFailureKind.captureFailed,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryPhotoCameraScreen(
          platform: FakeCameraPlatform(session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take POD photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not captured'), findsOneWidget);
    expect(find.text('Take POD photo'), findsOneWidget);
  });

  testWidgets('reports an unavailable rear camera with file fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryPhotoCameraScreen(
          platform: FakeCameraPlatform(
            failure: const DeliveryPhotoCameraFailure(
              DeliveryPhotoCameraFailureKind.unavailable,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('rear camera is unavailable'), findsOneWidget);
    expect(find.text('Retry camera'), findsOneWidget);
    expect(find.text('Use file chooser instead'), findsOneWidget);
  });

  testWidgets('returns a cancelled state and releases the camera', (
    tester,
  ) async {
    final session = FakeCameraSession();
    DeliveryPhotoCaptureResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<DeliveryPhotoCaptureResult>(
                  builder: (_) => DeliveryPhotoCameraScreen(
                    platform: FakeCameraPlatform(session: session),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result?.status, DeliveryPhotoCaptureStatus.cancelled);
    expect(session.disposed, isTrue);
  });
}
