// Synthetic local-browser harness. No accounts, secrets or live API access.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:file_selector/file_selector.dart';
import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/batch/presentation/final_mile_batch_screen.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture_result.dart';
import 'package:aisley_app/features/linehaul/presentation/linehaul_controller.dart';
import 'package:aisley_app/features/linehaul/presentation/linehaul_screen.dart';

import '../features/batch/fixtures/final_mile_batch_screen_fixture.dart';
import '../features/delivery/fixtures/delivery_screen_fixture.dart';
import '../features/linehaul/linehaul_fixture.dart';

late SemanticsHandle semantics;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  runApp(const SyncFixture());
}

class SyncFixture extends StatefulWidget {
  const SyncFixture({super.key});
  @override
  State<SyncFixture> createState() => _SyncFixtureState();
}

class _SyncFixtureState extends State<SyncFixture> {
  final auth = deliveryAuthController();
  final linehaulRepo = FakeLinehaulRepository();
  late final linehaul = LinehaulController(linehaulRepo);
  final batchesRepo = WidgetBatchRepository();
  late final parcels = WidgetParcelRepository(batchesRepo);
  late final batches = FinalMileBatchController(
    repository: batchesRepo,
    parcelRepository: parcels,
  );
  final deliveryRepo = WidgetDeliveryRepository()
    ..taskStatus = 'delivery_accepted';
  late final delivery = DeliveryController(deliveryRepository: deliveryRepo);
  final feature = Uri.base.queryParameters['feature'] ?? 'linehaul';
  @override
  void initState() {
    super.initState();
    deliveryRepo.deliveryContext = deliveryRepo.deliveryContext.copyWith(
      status: 'delivery_accepted',
    );
    delivery.tasks = [
      outForDeliveryTask.copyWith(rawStatus: 'delivery_accepted'),
    ];
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildCourierTheme(Brightness.light),
    darkTheme: buildCourierTheme(Brightness.dark),
    themeMode: Uri.base.queryParameters['theme'] == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          Uri.base.queryParameters['text'] == 'large' ? 2 : 1,
        ),
      ),
      child: child!,
    ),
    home: switch (feature) {
      'batch' => FinalMileBatchDetailScreen(
        authController: auth,
        batchController: batches,
        scheduleId: 'schedule-1',
      ),
      'delivery' => DeliveryTaskScreen(
        authController: auth,
        deliveryController: delivery,
        task: delivery.tasks.single,
        photoCaptureLauncher: WidgetPhotoCaptureLauncher(
          result: DeliveryPhotoCaptureResult.captured(
            XFile.fromData(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAEklEQVR4nGMQKl/wHx9mGBkKAM8iigGRRz6+AAAAAElFTkSuQmCC',
              ),
              name: 'synthetic-pod.png',
              mimeType: 'image/png',
            ),
          ),
        ),
      ),
      _ => LinehaulScreen(controller: linehaul, authController: auth),
    },
  );
  @override
  void dispose() {
    auth.dispose();
    linehaul.dispose();
    batches.dispose();
    delivery.dispose();
    semantics.dispose();
    super.dispose();
  }
}
