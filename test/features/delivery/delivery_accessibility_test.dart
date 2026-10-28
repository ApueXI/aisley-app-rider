import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';

import 'dart:convert';

import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import '../auth/fixtures/registration_screen_fixture.dart';
import 'fixtures/delivery_screen_fixture.dart';

void main() {
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest(
      'POD selection, preview, COD and pending review: ${scenario.name}',
      scenario,
      (tester) async {
        final repository = WidgetDeliveryRepository();
        final controller = DeliveryController(deliveryRepository: repository)
          ..tasks = [outForDeliveryTask];
        final auth = deliveryAuthController();
        final image = await TestImagePicker().openFile();
        final launcher = WidgetPhotoCaptureLauncher(
          result: DeliveryPhotoCaptureResult.captured(image!),
        );
        await tester.pumpWidget(
          scenario.app(
            DeliveryTaskScreen(
              authController: auth,
              deliveryController: controller,
              task: outForDeliveryTask,
              photoCaptureLauncher: launcher,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        await focusByKeyboard(
          tester,
          find.widgetWithText(FilledButton, 'Open camera for POD'),
        );
        expect(launcher.captureCalls, 0);
        expect(repository.uploadedPhoto, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await reveal(tester, find.byType(Image).first);
        expect(
          find.bySemanticsLabel(RegExp('Selected proof photo preview')),
          findsOneWidget,
        );
        await reveal(tester, find.text('Retake photo'));
        await checkAccessibility(tester);
        final delivered = find.widgetWithText(FilledButton, 'Delivered');
        await reveal(tester, delivered);
        expect(tester.widget<FilledButton>(delivered).onPressed, isNull);
        expect(repository.uploadedPhoto, isNull);
        await reveal(tester, find.text('Cash due'));
        expect(find.text('Cash due'), findsOneWidget);
        expect(find.text('PHP 115.00'), findsOneWidget);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse,
        );
        await checkAccessibility(tester);
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await focusByKeyboard(tester, find.byType(CheckboxListTile));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
        await checkAccessibility(tester);
        await reveal(tester, delivered);
        expect(tester.widget<FilledButton>(delivered).onPressed, isNotNull);
        await tester.tap(delivered);
        await tester.pumpAndSettle();
        expect(find.text('Confirm delivery'), findsOneWidget);
        expect(repository.completionEvidenceId, isNull);
        await focusByKeyboard(
          tester,
          find.widgetWithText(TextButton, 'Cancel'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Delivered'));
        await checkAccessibility(tester);
        expect(find.text('Delivered'), findsOneWidget);
        expect(
          controller.completions[outForDeliveryTask.id]?.isDelivered,
          isNot(true),
        );
        /*
         * Acknowledging cash enables the confirmation step only. The server
         * mutation still waits for the separate Delivered confirmation.
         */
        expect(repository.completionEvidenceId, isNull);
        expect(find.byType(AlertDialog), findsNothing);
        await unmount(tester, [controller, auth]);
      },
    );
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'POD validation and unavailable file recovery: ${scenario.name}',
      scenario,
      (tester) async {
        final repository = WidgetDeliveryRepository()
          ..proofError = const ApiException(
            statusCode: 422,
            code: 'VALIDATION_ERROR',
            message: 'Private diagnostic',
            fieldErrors: {
              'photo': ['Invalid photo.'],
            },
          );
        final controller = DeliveryController(deliveryRepository: repository)
          ..tasks = [outForDeliveryTask];
        final auth = deliveryAuthController();
        await controller.submitProof(
          outForDeliveryTask,
          photo: DeliveryPhotoSelection(
            path: null,
            fileName: 'test.png',
            bytes: base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9AAAAAElFTkSuQmCC',
            ),
          ),
        );
        await tester.pumpWidget(
          scenario.app(
            DeliveryTaskScreen(
              authController: auth,
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
        await checkScrollableAccessibility(tester);
        expect(find.text('Delivered'), findsNothing);
        await reveal(tester, find.text('Refresh task'));
        await focusByKeyboard(
          tester,
          find.widgetWithText(TextButton, 'Refresh task'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(repository.uploadedPhoto, isNull);
        expect(repository.completionEvidenceId, isNull);
        await checkScrollableAccessibility(tester);
        await unmount(tester, [controller, auth]);
      },
    );
  }
}
