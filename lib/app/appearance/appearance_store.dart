import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'appearance_controller.dart';

class DeviceAppearanceStore implements AppearanceStore {
  DeviceAppearanceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const key = 'courier.appearance_v1';

  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}
