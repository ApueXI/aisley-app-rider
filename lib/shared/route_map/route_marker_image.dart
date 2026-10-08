import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<Uint8List> routeMarkerImage(
  String label,
  Color color,
  Color foreground,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(const Offset(32, 32), 30, Paint()..color = color);
  canvas.drawCircle(
    const Offset(32, 32),
    29,
    Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: foreground,
        fontSize: 27,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(32 - painter.width / 2, 32 - painter.height / 2),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}
