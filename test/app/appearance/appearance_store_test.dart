import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/app/appearance/appearance_controller.dart';
import 'package:aisley_app/app/appearance/appearance_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('device appearance persists separately from the bearer token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'courier_sanctum_token': 'synthetic-token',
    });
    final controller = AppearanceController(
      store: DeviceAppearanceStore(),
      defaultMode: ThemeMode.system,
    );
    await controller.select(ThemeMode.dark);
    const secure = FlutterSecureStorage();
    expect(await secure.read(key: 'courier_sanctum_token'), 'synthetic-token');
    await secure.delete(key: 'courier_sanctum_token');
    final restored = AppearanceController(
      store: DeviceAppearanceStore(),
      defaultMode: ThemeMode.system,
    );
    await restored.restore();
    expect(restored.mode, ThemeMode.dark);
    controller.dispose();
    restored.dispose();
  });
}
