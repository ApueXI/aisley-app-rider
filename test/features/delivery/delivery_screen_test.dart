import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/domain/delivery_proof_photo.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture_result.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

import 'fixtures/delivery_screen_fixture.dart';

void main() {
  testWidgets(
    'camera capture can be previewed, replaced, removed, and uploaded',
    (tester) async {
      final repository = WidgetDeliveryRepository();
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[outForDeliveryTask];
      final launcher = WidgetPhotoCaptureLauncher(
        result: DeliveryPhotoCaptureResult.captured(
          XFile.fromData(
            Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
            path: '/tmp/captured.jpg',
            mimeType: 'image/jpeg',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: deliveryAuthController(),
            deliveryController: controller,
            task: outForDeliveryTask,
            photoCaptureLauncher: launcher,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openCamera = find.widgetWithText(
        FilledButton,
        'Open camera for POD',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(openCamera);
      await tester.pumpAndSettle();

      expect(launcher.captureCalls, 1);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Retake photo'), findsOneWidget);
      expect(find.text('Replace from files'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);

      final submitPhoto = find.widgetWithText(
        FilledButton,
        'Submit photo proof',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(submitPhoto);
      await tester.pumpAndSettle();

      expect(repository.uploadedPhoto?.fileName, 'captured.jpg');
      expect(find.textContaining('Photo proof received.'), findsOneWidget);
      await tester.ensureVisible(find.text('Submitted photo'));
      await tester.pumpAndSettle();
      expect(find.text('Submitted photo'), findsOneWidget);
      expect(
        controller.proofPhotoStatuses['proof-1'],
        ProofPhotoLoadStatus.loaded,
      );
    },
  );

  testWidgets('camera denial is explicit and file fallback remains available', (
    tester,
  ) async {
    final controller = DeliveryController(
      deliveryRepository: WidgetDeliveryRepository(),
    )..tasks = <PickupTask>[outForDeliveryTask];

    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: deliveryAuthController(),
          deliveryController: controller,
          task: outForDeliveryTask,
          photoCaptureLauncher: WidgetPhotoCaptureLauncher(
            result: const DeliveryPhotoCaptureResult.permissionDenied(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openCamera = find.widgetWithText(FilledButton, 'Open camera for POD');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(openCamera);
    await tester.pumpAndSettle();

    expect(find.textContaining('Camera permission was denied'), findsOneWidget);
    expect(find.text('Choose photo file'), findsOneWidget);
    expect(find.textContaining('Photo proof received.'), findsNothing);
  });

  testWidgets('non-Android targets show only the file chooser', (tester) async {
    final controller = DeliveryController(
      deliveryRepository: WidgetDeliveryRepository(),
    )..tasks = <PickupTask>[outForDeliveryTask];

    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: deliveryAuthController(),
          deliveryController: controller,
          task: outForDeliveryTask,
          photoCaptureLauncher: WidgetPhotoCaptureLauncher(
            supported: false,
            result: const DeliveryPhotoCaptureResult.unavailable(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open camera for POD'), findsNothing);
    expect(find.text('Choose photo'), findsOneWidget);
  });

  testWidgets(
    'shows Delivered intent after photo proof 202 while Logistics validation is pending',
    (tester) async {
      final repository = WidgetDeliveryRepository();
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[outForDeliveryTask];
      final proofSubmitted = await controller.submitProof(
        outForDeliveryTask,
        photo: DeliveryPhotoSelection(
          path: null,
          fileName: 'proof.jpg',
          bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
        ),
      );

      expect(proofSubmitted, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: deliveryAuthController(),
            deliveryController: controller,
            task: outForDeliveryTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ORD-100'), findsOneWidget);
      expect(find.text('WB-100'), findsOneWidget);
      expect(find.textContaining('Photo proof received.'), findsOneWidget);
      final submitIntent = find.text('Submit Delivered intent');
      await tester.ensureVisible(submitIntent);
      await tester.pumpAndSettle();
      expect(submitIntent, findsOneWidget);
      expect(find.text('Delivery completed by the server.'), findsNothing);

      await tester.tap(submitIntent);
      await tester.pumpAndSettle();
      expect(find.text('Confirm COD collection'), findsOneWidget);
      expect(find.text('Amount to collect: PHP 115.00'), findsOneWidget);
      expect(find.text('I collected PHP 115.00 in full.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit intent'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('I collected PHP 115.00 in full.'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit intent'));
      await tester.pumpAndSettle();

      expect(repository.completionEvidenceId, 'proof-1');
      expect(repository.codCollected, isTrue);
      expect(
        find.textContaining('Completion intent accepted by the server.'),
        findsOneWidget,
      );
      expect(find.text('Delivery completed by the server.'), findsNothing);
    },
  );

  testWidgets('failed photo upload shows the error, not pending delivery', (
    tester,
  ) async {
    final repository = WidgetDeliveryRepository()
      ..proofError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'The photo field is invalid.',
        fieldErrors: {
          'photo': ['The photo field is invalid.'],
        },
      );
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[outForDeliveryTask];
    final submitted = await controller.submitProof(
      outForDeliveryTask,
      photo: DeliveryPhotoSelection(
        path: null,
        fileName: 'proof.jpg',
        bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
      ),
    );

    expect(submitted, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: deliveryAuthController(),
          deliveryController: controller,
          task: outForDeliveryTask,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The photo field is invalid.'), findsNothing);
    expect(find.textContaining('Choose a JPEG, PNG or WebP'), findsOneWidget);
    expect(find.text('Refresh task'), findsOneWidget);
    expect(find.textContaining('Photo proof received.'), findsNothing);
    expect(find.text('Submit Delivered intent'), findsNothing);
    await tester.ensureVisible(find.text('Refresh task'));
    await tester.pumpAndSettle();
    final readsBeforeRefresh = repository.deliveryReads;
    await tester.tap(find.text('Refresh task'));
    await tester.pumpAndSettle();
    expect(repository.deliveryReads, greaterThan(readsBeforeRefresh));
    expect(repository.uploadedPhoto, isNull);
    expect(repository.completionEvidenceId, isNull);
  });

  testWidgets(
    'missing COD total blocks the intent without using parcel price',
    (tester) async {
      final repository = WidgetDeliveryRepository()
        ..deliveryContext = const DeliveryContext(
          taskId: 'delivery-task-1',
          status: 'out_for_delivery',
          revision: 7,
          paymentMethod: 'cod',
          paymentStatus: 'pending',
          currency: 'PHP',
        );
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[outForDeliveryTask];
      await controller.submitProof(
        outForDeliveryTask,
        photo: DeliveryPhotoSelection(
          path: null,
          fileName: 'proof.jpg',
          bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: deliveryAuthController(),
            deliveryController: controller,
            task: outForDeliveryTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitIntent = find.text('Submit Delivered intent');
      await tester.ensureVisible(submitIntent);
      await tester.pumpAndSettle();
      await tester.tap(submitIntent);
      await tester.pumpAndSettle();

      expect(find.text('Confirm COD collection'), findsNothing);
      expect(find.textContaining('cash amount'), findsWidgets);
      expect(repository.completionEvidenceId, isNull);
    },
  );
}
