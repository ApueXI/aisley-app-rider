import 'dart:ui' as ui;

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/shared/presentation/private_image_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final source in [const Size(240, 480), const Size(480, 240)]) {
    testWidgets(
      'preview shows all four image corners $source and clears authorization',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final bytes = await tester.runAsync(() => _fourCorners(source));
        final changes = ValueNotifier<bool>(true);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCourierTheme(Brightness.light),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RepaintBoundary(
                        key: boundary,
                        child: PrivateImageScreen(
                          title: 'Synthetic OR',
                          changes: changes,
                          isAuthorized: () => changes.value,
                          readBytes: () => bytes,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open preview'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open preview'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(bytes!),
            tester.element(find.byType(PrivateImageScreen)),
          ),
        );
        await tester.pump();
        final raw = tester.renderObject<RenderImage>(find.byType(RawImage));
        expect(raw.image, isNotNull);
        final fitted = applyBoxFit(BoxFit.contain, source, raw.size);
        final painted = Alignment.center.inscribe(
          fitted.destination,
          Offset.zero & raw.size,
        );
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final offset = raw.localToGlobal(Offset.zero, ancestor: render);
        await tester.runAsync(() async {
          final snapshot = await render.toImage();
          final rgba = (await snapshot.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final corners = [
            painted.topLeft + const Offset(4, 4),
            painted.topRight + const Offset(-4, 4),
            painted.bottomLeft + const Offset(4, -4),
            painted.bottomRight + const Offset(-4, -4),
          ];
          const expected = [
            Colors.red,
            Colors.green,
            Colors.blue,
            Colors.orange,
          ];
          for (var i = 0; i < corners.length; i++) {
            final point = corners[i] + offset;
            final pixel =
                (point.dy.floor() * snapshot.width + point.dx.floor()) * 4;
            expect(
              Color.fromARGB(
                rgba.getUint8(pixel + 3),
                rgba.getUint8(pixel),
                rgba.getUint8(pixel + 1),
                rgba.getUint8(pixel + 2),
              ).toARGB32(),
              expected[i].toARGB32(),
            );
          }
          snapshot.dispose();
        });
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
        await tester.tap(find.text('Fit image'));
        await tester.pump();
        changes.value = false;
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        expect(find.text('This image is no longer available.'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Open preview'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        changes.dispose();
      },
    );
  }
}

Future<Uint8List> _fourCorners(Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final half = Size(size.width / 2, size.height / 2);
  final offsets = [
    Offset.zero,
    Offset(half.width, 0),
    Offset(0, half.height),
    Offset(half.width, half.height),
  ];
  const colors = [Colors.red, Colors.green, Colors.blue, Colors.orange];
  for (var i = 0; i < offsets.length; i++) {
    canvas.drawRect(offsets[i] & half, Paint()..color = colors[i]);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}
