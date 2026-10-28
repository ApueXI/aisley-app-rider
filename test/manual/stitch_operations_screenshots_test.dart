import 'dart:io';
import 'dart:ui' as ui;

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/courier_map_security.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/batch/presentation/final_mile_batch_screen.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture_result.dart';
import 'package:aisley_app/features/linehaul/presentation/linehaul_controller.dart';
import 'package:aisley_app/features/linehaul/presentation/linehaul_screen.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:aisley_app/features/pickup/presentation/pickup_screen.dart';
import 'package:aisley_app/shared/route_map/route_map_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector/file_selector.dart';

import '../features/batch/fixtures/final_mile_batch_screen_fixture.dart';
import '../features/delivery/fixtures/delivery_screen_fixture.dart';
import '../features/linehaul/linehaul_fixture.dart';
import '../features/pickup/fixtures/pickup_route_repository.dart';
import '../features/delivery_route/delivery_route_contract_test.dart'
    show RouteTestStorage;

const _captureEnabled = bool.fromEnvironment(
  'CAPTURE_STITCH_OPERATIONS',
  defaultValue: false,
);
const _sdkFonts = String.fromEnvironment(
  'FLUTTER_FONT_DIR',
  defaultValue: '/home/cred/develop/flutter/bin/cache/artifacts/material_fonts',
);

void main() {
  if (!_captureEnabled) return;

  setUpAll(() async {
    final body = FontLoader('Roboto');
    for (final file in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      body.addFont(
        File('$_sdkFonts/$file')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await body.load();
    await (FontLoader('MaterialIcons')..addFont(
          File('$_sdkFonts/MaterialIcons-Regular.otf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
  });

  for (final screen in [
    'offered-parcel-decision',
    'pickup-matched-candidate',
    'delivery-photo-cod',
    'final-mile-batch',
    'route-fallback',
    'linehaul-trip',
    'delivery-pending-review',
  ]) {
    testWidgets('captures $screen', (tester) async {
      _setViewport(tester);
      final boundary = GlobalKey();
      switch (screen) {
        case 'offered-parcel-decision':
          await _captureOfferedParcelDecision(tester, boundary);
          break;
        case 'pickup-matched-candidate':
          await _captureMatchedPickup(tester, boundary);
          break;
        case 'delivery-photo-cod':
          await _captureDeliveryPhotoAndCash(tester, boundary);
          break;
        case 'final-mile-batch':
          await _captureBatch(tester, boundary);
          break;
        case 'route-fallback':
          await _captureRouteFallback(tester, boundary);
          break;
        case 'linehaul-trip':
          await _captureLinehaul(tester, boundary);
          break;
        case 'delivery-pending-review':
          await _capturePendingReview(tester, boundary);
          break;
      }
      expect(tester.takeException(), isNull);
    });
  }
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(780, 2000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpCaptureApp(
  WidgetTester tester,
  GlobalKey boundary,
  Widget screen, {
  Widget Function(Widget child)? wrapper,
}) async {
  Widget body = RepaintBoundary(key: boundary, child: screen);
  if (wrapper != null) body = wrapper(body);
  await tester.pumpWidget(
    MaterialApp(theme: buildCourierTheme(Brightness.light), home: body),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey boundary, String name) {
  return tester.runAsync(() async {
    final renderObject =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await renderObject.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('build/stitch-ui/operations');
    await folder.create(recursive: true);
    final fileName = name.endsWith('.png') ? name : '$name.png';
    await File('${folder.path}/$fileName').writeAsBytes(
      png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
    );
    image.dispose();
  });
}

Future<void> _captureOfferedParcelDecision(
  WidgetTester tester,
  GlobalKey boundary,
) async {
  final repository = WidgetBatchRepository();
  final controller = FinalMileBatchController(
    repository: repository,
    parcelRepository: WidgetParcelRepository(repository),
  );
  final auth = batchAuthController();
  await _pumpCaptureApp(
    tester,
    boundary,
    FinalMileBatchDetailScreen(
      authController: auth,
      batchController: controller,
      scheduleId: 'schedule-1',
    ),
  );
  expect(find.text('Accept parcel'), findsNWidgets(2));
  expect(find.text('Reject parcel'), findsNWidgets(2));
  await tester.ensureVisible(find.text('Accept parcel').first);
  await _capture(tester, boundary, '03-offered-parcel-decision.png');
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  auth.dispose();
}

Future<void> _captureMatchedPickup(
  WidgetTester tester,
  GlobalKey boundary,
) async {
  final auth = deliveryAuthController();
  final controller = PickupController(
    pickupRepository: _MatchedPickupRepository(),
  );
  final task = PickupTask(
    id: 'task-demo-2049',
    leg: PickupTaskLeg.firstMile,
    rawStatus: 'accepted',
    revision: 4,
    order: PickupOrderReference(reference: 'ORD-DEMO-2049'),
    waybill: PickupWaybillReference(reference: 'WB-DEMO-2049'),
    pickup: PickupLocation(
      name: 'Sample Seller',
      addressLine1: '20 Market Street',
      barangay: 'Poblacion',
      cityMunicipality: 'Makati City',
      province: 'Metro Manila',
      region: 'NCR',
      postalCode: '1200',
    ),
    destinationArea: PickupLocation(
      cityMunicipality: 'Pasig City',
      province: 'Metro Manila',
    ),
    schedule: PickupSchedule(
      id: 'schedule-demo-2049',
      reference: 'SCH-DEMO-2049',
      startsAt: DateTime.utc(2026, 10, 28, 1),
      endsAt: DateTime.utc(2026, 10, 28, 4),
    ),
  );
  await _pumpCaptureApp(
    tester,
    boundary,
    PickupTaskDetailScreen(
      authController: auth,
      pickupController: controller,
      task: task,
    ),
  );
  await tester.scrollUntilVisible(
    find.text('Check QR match'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(find.byType(TextField), 'WB-DEMO-2049');
  await tester.ensureVisible(find.text('Check QR match'));
  await tester.tap(find.text('Check QR match'));
  await tester.pumpAndSettle();
  await _capture(tester, boundary, '04-pickup-matched-candidate.png');
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  auth.dispose();
}

Future<void> _captureDeliveryPhotoAndCash(
  WidgetTester tester,
  GlobalKey boundary,
) async {
  final auth = deliveryAuthController();
  final repository = WidgetDeliveryRepository();
  final controller = DeliveryController(deliveryRepository: repository)
    ..tasks = <PickupTask>[outForDeliveryTask];
  final proofBytes =
      await tester.runAsync(_syntheticProofPng) ??
      (throw StateError('Could not generate the synthetic POD image.'));
  await tester.runAsync(() async {
    final artifactDirectory = Directory('build/stitch-ui/operations');
    await artifactDirectory.create(recursive: true);
    await File('${artifactDirectory.path}/synthetic-pod-source.png')
        .writeAsBytes(proofBytes);
    return true;
  });
  final launcher = _SyntheticPhotoCapture(proofBytes);
  await _pumpCaptureApp(
    tester,
    boundary,
    DeliveryTaskScreen(
      authController: auth,
      deliveryController: controller,
      task: outForDeliveryTask,
      photoCaptureLauncher: launcher,
    ),
  );
  await tester.ensureVisible(find.text('I collected PHP 115.00 in full.'));
  expect(
    tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
    isFalse,
  );
  expect(proofBytes.length, greaterThan(1000));
  await _capture(tester, boundary, '05-delivery-cod-unchecked.png');
  await tester.ensureVisible(find.text('Open camera for POD'));
  await tester.tap(find.text('Open camera for POD'));
  await tester.pumpAndSettle();
  expect(launcher.captureCalls, 1);
  expect(find.text('Retake photo'), findsOneWidget);
  final deliveryScreenContext = tester.element(find.byType(Scaffold).last);
  await tester.runAsync(
    () => precacheImage(MemoryImage(proofBytes), deliveryScreenContext),
  );
  await tester.pump();
  await tester.ensureVisible(find.byType(Image).first);
  await _capture(tester, boundary, '05b-delivery-photo-selected.png');
  await tester.scrollUntilVisible(
    find.text('Refresh completion status'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(find.text('Refresh completion status'), findsOneWidget);
  await _capture(tester, boundary, '05c-delivery-delivered-control.png');
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  auth.dispose();
}

Future<void> _captureBatch(WidgetTester tester, GlobalKey boundary) async {
  final repository = WidgetBatchRepository()..acceptedIds.add('task-2');
  final parcels = WidgetParcelRepository(repository);
  final controller = FinalMileBatchController(
    repository: repository,
    parcelRepository: parcels,
  );
  final auth = batchAuthController();
  await _pumpCaptureApp(
    tester,
    boundary,
    FinalMileBatchDetailScreen(
      authController: auth,
      batchController: controller,
      scheduleId: 'schedule-1',
    ),
  );
  await tester.ensureVisible(find.text('Accept parcel').first);
  await _capture(tester, boundary, '11-final-mile-batch.png');
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  auth.dispose();
}

Future<void> _captureRouteFallback(
  WidgetTester tester,
  GlobalKey boundary,
) async {
  final repository = PickupRouteRepository()
    ..response = emptyPickupRoute(status: 'unavailable');
  final controller = PickupController(pickupRepository: repository);
  await _pumpCaptureApp(
    tester,
    boundary,
    PickupRouteScreen(
      pickupController: controller,
      scheduleId: 'schedule-a',
      schedule: const PickupSchedule(
        id: 'schedule-a',
        reference: 'SCH-DEMO-2050',
      ),
    ),
  );
  await _capture(tester, boundary, '14-route-fallback.png');
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
}

Future<void> _captureLinehaul(WidgetTester tester, GlobalKey boundary) async {
  final controller = LinehaulController(FakeLinehaulRepository());
  final auth = deliveryAuthController();
  final config = const AppConfig(baseUrl: 'https://api.example.test');
  final security = CourierMapSecurity(
    config: config,
    client: ApiClient(config: config, tokenStorage: RouteTestStorage()),
  );
  await controller.load();
  await _pumpCaptureApp(
    tester,
    boundary,
    LinehaulScreen(controller: controller, authController: auth),
    wrapper: (child) => RouteMapScope(
      security: security,
      renderer: (_, _, _) =>
          const SizedBox(height: 210, child: Center(child: Text('Route map'))),
      child: child,
    ),
  );
  await _capture(tester, boundary, '15-linehaul-trip.png');
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  auth.dispose();
  security.dispose();
}

Future<void> _capturePendingReview(
  WidgetTester tester,
  GlobalKey boundary,
) async {
  final auth = deliveryAuthController();
  final repository = WidgetDeliveryRepository();
  final controller = DeliveryController(deliveryRepository: repository)
    ..tasks = <PickupTask>[outForDeliveryTask];
  final proofBytes =
      await tester.runAsync(_syntheticProofPng) ??
      (throw StateError('Could not generate the synthetic POD image.'));
  final photo = DeliveryPhotoSelection(
    path: null,
    fileName: 'synthetic-proof.png',
    bytes: proofBytes,
  );
  expect(
    await controller.submitDelivered(
      outForDeliveryTask,
      photo: photo,
      confirmedCollection: const DeliveryCodCollection(
        amount: '115.00',
        currency: 'PHP',
      ),
    ),
    isTrue,
  );
  await _pumpCaptureApp(
    tester,
    boundary,
    DeliveryTaskScreen(
      authController: auth,
      deliveryController: controller,
      task: outForDeliveryTask,
    ),
  );
  await _capture(tester, boundary, '16-delivery-pending-review.png');
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  auth.dispose();
}

class _MatchedPickupRepository extends PickupRouteRepository {
  @override
  Future<WaybillResolution> resolveWaybill(String payload) async =>
      const WaybillResolution(
        taskId: 'task-demo-2049',
        orderReference: 'ORD-DEMO-2049',
        waybillReference: 'WB-DEMO-2049',
        taskStatus: 'accepted',
      );
}

class _SyntheticPhotoCapture implements DeliveryPhotoCaptureLauncher {
  _SyntheticPhotoCapture(this.proofBytes);

  final Uint8List proofBytes;
  var captureCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<DeliveryPhotoCaptureResult> capture(BuildContext context) async {
    captureCalls++;
    return DeliveryPhotoCaptureResult.captured(
      XFile.fromData(
        proofBytes,
        name: 'synthetic-pod.png',
        mimeType: 'image/png',
      ),
    );
  }
}

Future<Uint8List> _syntheticProofPng() async {
  const size = Size(480, 320);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bounds = Offset.zero & size;
  final background = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDCE9EE), Color(0xFFB8CBD1)],
    ).createShader(bounds);
  canvas.drawRect(bounds, background);
  canvas.drawRect(
    Rect.fromLTWH(0, 232, size.width, 88),
    Paint()..color = const Color(0xFF9CAFAF),
  );
  canvas.drawCircle(
    const Offset(390, 74),
    34,
    Paint()..color = const Color(0xFFE4B66C),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(111, 82, 255, 171),
      const Radius.circular(12),
    ),
    Paint()..color = const Color(0xFF9B684B),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(126, 96, 225, 145),
      const Radius.circular(8),
    ),
    Paint()..color = const Color(0xFFC88D64),
  );
  canvas.drawRect(
    const Rect.fromLTWH(222, 96, 34, 145),
    Paint()..color = const Color(0xFFE7C78E),
  );
  canvas.drawLine(
    const Offset(127, 167),
    const Offset(350, 167),
    Paint()
      ..color = const Color(0xFFE7C78E)
      ..strokeWidth = 8,
  );
  final image = await recorder.endRecording().toImage(480, 320);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
