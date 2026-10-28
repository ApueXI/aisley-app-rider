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
  testWidgets('Back protects an unsent POD photo without submitting proof', (
    tester,
  ) async {
    final repository = WidgetDeliveryRepository();
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[outForDeliveryTask];
    final auth = deliveryAuthController();
    final launcher = WidgetPhotoCaptureLauncher(
      result: DeliveryPhotoCaptureResult.captured(
        XFile.fromData(
          Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
          name: 'synthetic-pod.jpg',
          mimeType: 'image/jpeg',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DeliveryTaskScreen(
                    authController: auth,
                    deliveryController: controller,
                    task: outForDeliveryTask,
                    photoCaptureLauncher: launcher,
                  ),
                ),
              ),
              child: const Text('Open delivery'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open delivery'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Open camera for POD'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Open camera for POD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open camera for POD'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Retake photo'), findsOneWidget);
    expect(repository.uploadedPhoto, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open delivery'), findsOneWidget);
    expect(repository.uploadedPhoto, isNull);
    expect(repository.completionEvidenceId, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });

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

      final submitPhoto = find.widgetWithText(FilledButton, 'Delivered');
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(submitPhoto);
      await tester.pumpAndSettle();
      expect(repository.uploadedPhoto, isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.widget<FilledButton>(submitPhoto).onPressed, isNull);
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(find.text('Cash due'), findsOneWidget);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.text('I collected PHP 115.00 in full.'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        submitPhoto,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submitPhoto).onPressed, isNotNull);
      await tester.tap(submitPhoto);
      await tester.pumpAndSettle();
      expect(find.text('Confirm delivery'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delivered'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.uploadedPhoto?.fileName, 'captured.jpg');
      await tester.scrollUntilVisible(
        find.text('Submitted photo proof'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Submitted photo proof'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('Choose photo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
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
      expect(find.text('Waybill WB-100'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Photo proof received.'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Photo proof received.'), findsOneWidget);
      final submitIntent = find.text('Delivered');
      await tester.scrollUntilVisible(
        submitIntent,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(submitIntent, findsOneWidget);
      expect(find.text('Delivery completed by the server.'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.text('Cash due'), findsOneWidget);
      expect(find.text('PHP 115.00'), findsOneWidget);
      expect(find.text('I collected PHP 115.00 in full.'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(
                    of: submitIntent,
                    matching: find.byType(FilledButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        submitIntent,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(submitIntent);
      await tester.pumpAndSettle();
      expect(find.text('Confirm delivery'), findsOneWidget);
      expect(
        find.text('Cash collection acknowledged: PHP 115.00.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(FilledButton, 'Delivered'),
              ),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delivered'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.completionEvidenceId, 'proof-1');
      expect(repository.codCollected, isTrue);
      expect(
        find.textContaining('Awaiting Logistics validation'),
        findsWidgets,
      );
      expect(find.text('Delivery completed by the server.'), findsNothing);
      expect(find.text('Back to delivery work'), findsOneWidget);
    },
  );

  testWidgets('a changed payable total clears the collection acknowledgment', (
    tester,
  ) async {
    final repository = WidgetDeliveryRepository();
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[outForDeliveryTask];
    final auth = deliveryAuthController();
    final launcher = WidgetPhotoCaptureLauncher(
      result: DeliveryPhotoCaptureResult.captured(
        XFile.fromData(
          Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
          name: 'synthetic-pod.jpg',
          mimeType: 'image/jpeg',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: auth,
          deliveryController: controller,
          task: outForDeliveryTask,
          photoCaptureLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open camera for POD'));
    await tester.tap(find.text('Open camera for POD'));
    await tester.pumpAndSettle();

    final delivered = find.widgetWithText(FilledButton, 'Delivered');
    expect(tester.widget<FilledButton>(delivered).onPressed, isNotNull);

    repository.deliveryContext = const DeliveryContext(
      taskId: 'delivery-task-1',
      status: 'out_for_delivery',
      revision: 8,
      failedAttemptCount: 0,
      hub: PickupLocation(name: 'Makati Hub'),
      destination: PickupLocation(
        cityMunicipality: 'Pasig',
        province: 'Metro Manila',
      ),
      paymentMethod: 'cod',
      paymentStatus: 'pending',
      payableTotal: '116.00',
      currency: 'PHP',
    );
    await controller.loadDetails(outForDeliveryTask);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('PHP 116.00'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(repository.uploadedPhoto, isNull);
    await tester.scrollUntilVisible(
      delivered,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(delivered).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });

  testWidgets('uncertain Delivered retry retains its exact attempt key', (
    tester,
  ) async {
    final repository = WidgetDeliveryRepository()
      ..completionError = const ApiException.network('lost response');
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[outForDeliveryTask];
    final auth = deliveryAuthController();
    final photo = DeliveryPhotoSelection(
      path: null,
      fileName: 'synthetic-pod.jpg',
      bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
    );
    expect(
      await controller.submitProof(outForDeliveryTask, photo: photo),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: auth,
          deliveryController: controller,
          task: outForDeliveryTask,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final delivered = find.widgetWithText(FilledButton, 'Delivered');
    expect(tester.widget<FilledButton>(delivered).onPressed, isNotNull);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      delivered,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(delivered);
    await tester.tap(delivered);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delivered'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.completionKeys, hasLength(1));
    await tester.scrollUntilVisible(
      find.text('Retry Delivered'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Retry Delivered'), findsOneWidget);
    repository.completionError = null;

    await tester.drag(find.byType(ListView), const Offset(0, 180));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry Delivered'));
    await tester.tap(find.text('Retry Delivered'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm delivery'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delivered'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.completionKeys, hasLength(2));
    expect(repository.completionKeys.toSet(), hasLength(1));
    expect(find.text('Back to delivery work'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });

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
    await tester.scrollUntilVisible(
      find.textContaining('Choose a JPEG, PNG, or WebP'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Choose a JPEG, PNG, or WebP'), findsOneWidget);
    expect(find.text('Refresh task'), findsOneWidget);
    expect(find.textContaining('Photo proof received.'), findsNothing);
    expect(find.text('Delivered'), findsNothing);
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
          failedAttemptCount: 0,
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

      final submitIntent = find.text('Delivered');
      await tester.scrollUntilVisible(
        submitIntent,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(
                    of: submitIntent,
                    matching: find.byType(FilledButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      await tester.tap(submitIntent);
      await tester.pumpAndSettle();

      expect(find.text('Confirm COD collection'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.textContaining('cash amount'), findsWidgets);
      expect(repository.completionEvidenceId, isNull);
    },
  );
}
