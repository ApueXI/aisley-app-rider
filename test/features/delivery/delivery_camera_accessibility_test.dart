import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_camera_platform.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import 'fixtures/delivery_photo_camera_screen_fixture.dart';

void main() {
  for (final scenario in AccessibilityScenario.matrix) {
    for (final denied in [false, true]) {
      accessibilityTest(
        'POD camera ${denied ? 'denied' : 'ready'}: ${scenario.name}',
        scenario,
        (tester) async {
          final session = FakeCameraSession();
          final platform = FakeCameraPlatform(
            session: session,
            failure: denied
                ? const DeliveryPhotoCameraFailure(
                    DeliveryPhotoCameraFailureKind.permissionDenied,
                  )
                : null,
          );
          await tester.pumpWidget(
            scenario.app(DeliveryPhotoCameraScreen(platform: platform)),
          );
          await tester.pumpAndSettle();
          await checkAccessibility(tester);
          await focusByKeyboard(
            tester,
            find.widgetWithText(
              denied ? TextButton : FilledButton,
              denied ? 'Use file chooser instead' : 'Take POD photo',
            ),
          );
          expect(session.takePictureCalls, 0);
          await pressTab(tester);
          await pressTab(tester, reverse: true);
          await checkAccessibility(tester);
          if (denied) {
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(session.takePictureCalls, 0);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          if (!denied) expect(session.disposed, isTrue);
        },
      );
    }
  }
}
