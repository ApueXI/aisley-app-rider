import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_camera_platform.dart';

class FakeCameraPlatform implements DeliveryPhotoCameraPlatform {
  FakeCameraPlatform({this.session, this.failure});

  final DeliveryPhotoCameraSession? session;
  final DeliveryPhotoCameraFailure? failure;
  int openCalls = 0;

  @override
  Future<DeliveryPhotoCameraSession> openRearCamera() async {
    openCalls++;
    if (failure != null) throw failure!;
    return session!;
  }
}

class FakeCameraSession implements DeliveryPhotoCameraSession {
  FakeCameraSession({this.takeFailure});

  final DeliveryPhotoCameraFailure? takeFailure;
  int takePictureCalls = 0;
  bool disposed = false;

  @override
  double get aspectRatio => 1;

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);

  @override
  Future<XFile> takePicture() async {
    takePictureCalls++;
    if (takeFailure != null) throw takeFailure!;
    return XFile.fromData(
      Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
      path: '/tmp/captured.jpg',
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
