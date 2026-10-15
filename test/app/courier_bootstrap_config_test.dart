import 'dart:convert';

import 'package:aisley_app/app/courier_bootstrap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('configuration failure uses the existing startup retry screen', (
    tester,
  ) async {
    var configReads = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key != '.env') return null;
      configReads++;
      return ByteData.sublistView(utf8.encode('MAPS_ENABLED=invalid'));
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

    await tester.pumpWidget(const CourierBootstrapApp());
    await tester.pumpAndSettle();

    expect(configReads, 1);
    expect(find.text('The app could not start safely.'), findsOneWidget);
    expect(find.text('Starting AISLEY Courier…'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(configReads, 2);
    expect(find.text('The app could not start safely.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
