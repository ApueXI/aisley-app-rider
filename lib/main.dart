import 'core/chat_media/media_platform.dart';

import 'package:flutter/widgets.dart';

import 'app/courier_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cleanAbandonedChatMedia();
  runApp(const CourierBootstrapApp());
}
