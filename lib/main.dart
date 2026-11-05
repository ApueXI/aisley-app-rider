import 'app/appearance/appearance_controller.dart';
import 'app/appearance/appearance_scope.dart';
import 'app/appearance/appearance_store.dart';

import 'core/chat_media/media_platform.dart';

import 'package:flutter/material.dart';

import 'app/courier_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cleanAbandonedChatMedia();
  final appearance = AppearanceController(
    store: DeviceAppearanceStore(),
    defaultMode: ThemeMode.system,
  );
  await appearance.restore();
  runApp(
    AppearanceRoot(controller: appearance, child: const CourierBootstrapApp()),
  );
}
