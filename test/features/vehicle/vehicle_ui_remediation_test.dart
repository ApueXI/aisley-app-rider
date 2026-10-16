import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/vehicle/data/vehicle_repository.dart';
import 'package:aisley_app/features/vehicle/domain/vehicle_models.dart';
import 'package:aisley_app/features/vehicle/presentation/controllers/vehicle_controller.dart';
import 'package:aisley_app/features/vehicle/presentation/vehicle_screen.dart';
import 'package:aisley_app/shared/presentation/private_image_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import '../delivery/fixtures/delivery_screen_fixture.dart';

void main() {
  for (final operation in ['load', 'save', 'upload', 'preview']) {
    testWidgets(
      '$operation throttling blocks direct repeats until explicit retry',
      (tester) async {
        final repository = _VehicleRepo();
        final controller = VehicleController(vehicleRepository: repository);
        await controller.load();
        repository.throttledOperation = operation;
        Future<void> perform() async {
          switch (operation) {
            case 'load':
              await controller.load();
            case 'save':
              await controller.updateVehicle(
                changes: {'plate_number': 'NEW-123'},
              );
            case 'upload':
              await controller.uploadDocument(
                VehicleDocumentKind.officialReceipt,
                VehicleDocumentSelection(
                  path: '',
                  fileName: 'synthetic.png',
                  bytes: repository.bytes,
                ),
              );
            case 'preview':
              await controller.loadDocument(
                VehicleDocumentKind.officialReceipt,
              );
          }
        }

        await perform();
        final calls = repository.calls;
        expect(controller.canRetryRateLimit, false);
        await perform();
        await controller.retryDocument(VehicleDocumentKind.officialReceipt);
        await controller.retryUpdate();
        expect(repository.calls, calls);
        await tester.pump(const Duration(seconds: 3));
        expect(controller.canRetryRateLimit, true);
        expect(repository.calls, calls);
        repository.throttledOperation = null;
        await perform();
        expect(repository.calls, calls + 1);
        controller.dispose();
      },
    );
  }
  testWidgets('private reads deduplicate and ignore replies after scope loss', (
    tester,
  ) async {
    final repository = _VehicleRepo()
      ..pendingPreview = Completer<VehicleDocumentData>();
    final controller = VehicleController(vehicleRepository: repository);
    await controller.load();
    final first = controller.loadDocument(VehicleDocumentKind.officialReceipt);
    await controller.loadDocument(VehicleDocumentKind.officialReceipt);
    expect(repository.calls, 2);
    controller.clear();
    repository.pendingPreview!.complete(
      VehicleDocumentData(bytes: repository.bytes, contentType: 'image/png'),
    );
    await first;
    expect(
      controller.documentPreview(VehicleDocumentKind.officialReceipt),
      isNull,
    );
    expect(
      controller.documentPreviewStatus(VehicleDocumentKind.officialReceipt),
      VehicleDocumentPreviewStatus.idle,
    );
    controller.dispose();
  });
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest(
      'vehicle drafts and full preview ${scenario.name}',
      scenario,
      (tester) async {
        final repository = _VehicleRepo();
        final controller = VehicleController(vehicleRepository: repository);
        final auth = deliveryAuthController();
        await tester.pumpWidget(
          scenario.app(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VehicleScreen(
                        authController: auth,
                        vehicleController: controller,
                      ),
                    ),
                  ),
                  child: const Text('Open vehicle'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open vehicle'));
        await tester.pumpAndSettle();
        final plate = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Plate number',
        );
        await tester.scrollUntilVisible(
          plate,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(plate);
        await tester.enterText(plate, 'Unsent plate');
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await checkAccessibility(tester);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(plate).controller!.text,
          'Unsent plate',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('View current OR'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('View current OR'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View current OR'));
        await tester.pumpAndSettle();
        expect(find.byType(PrivateImageScreen), findsOneWidget);
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.fit, BoxFit.contain);
        expect(image.semanticLabel, 'Saved OR');
        await checkAccessibility(tester);
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
        await tester.tap(find.text('Fit image'));
        await tester.pump();
        await tester.tap(find.byTooltip('Close preview'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.text('Open vehicle'), findsOneWidget);
        expect(
          controller.documentPreview(VehicleDocumentKind.officialReceipt),
          isNull,
        );
        await unmount(tester, [controller, auth]);
      },
    );
  }
}

class _VehicleRepo implements VehicleRepository {
  int calls = 0;
  String? throttledOperation;
  Completer<VehicleDocumentData>? pendingPreview;
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9AAAAAElFTkSuQmCC',
  );
  void _read(String operation) {
    calls++;
    if (throttledOperation == operation) {
      throw const ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: 'Wait',
        retryAfter: Duration(seconds: 3),
      );
    }
  }

  CourierVehicle get vehicle => const CourierVehicle(
    id: 'vehicle-1',
    vehicleType: 'motorcycle',
    plateNumber: 'SYNTHETIC-123',
    revision: 1,
    officialReceipt: VehicleDocumentReference(
      id: 'or-1',
      url: '/api/v1/courier/vehicle/documents/official_receipt',
    ),
  );
  @override
  Future<CourierVehicle> fetchVehicle() async {
    _read('load');
    return vehicle;
  }

  @override
  Future<CourierVehicle> updateVehicle({
    required Map<String, Object?> changes,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    _read('save');
    return vehicle;
  }

  @override
  Future<CourierVehicle> uploadDocument({
    required VehicleDocumentKind kind,
    required VehicleDocumentSelection selection,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function())? onCancel,
  }) async {
    _read('upload');
    return vehicle;
  }

  @override
  Future<VehicleDocumentData> fetchDocument(VehicleDocumentKind kind) async {
    _read('preview');
    return pendingPreview?.future ??
        VehicleDocumentData(
          bytes: Uint8List.fromList(bytes),
          contentType: 'image/png',
        );
  }
}
