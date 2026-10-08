import 'package:aisley_app/app/courier_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logical phone sizes, production themes, and unmodified system text scaling.
class AccessibilityScenario {
  const AccessibilityScenario(this.size, this.scale, this.brightness);

  final Size size;
  final double scale;
  final Brightness brightness;

  static final matrix = [
    for (final size in [const Size(320, 640), const Size(390, 844)])
      for (final scale in [1.0, 2.0])
        for (final brightness in Brightness.values)
          AccessibilityScenario(size, scale, brightness),
  ];

  static final stress = matrix.where(
    (s) => s.size.width == 320 && s.scale == 2,
  );

  String get name => '${size.width.toInt()}px / ${scale}x / ${brightness.name}';

  SemanticsHandle configure(WidgetTester tester) {
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalErrorHandler?.call(details);
    };
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final semantics = tester.ensureSemantics();
    addTearDown(() {
      FlutterError.onError = originalErrorHandler;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return semantics;
  }

  Widget app(Widget home) => MaterialApp(
    theme: buildCourierTheme(Brightness.light),
    darkTheme: buildCourierTheme(Brightness.dark),
    themeMode: brightness == Brightness.light
        ? ThemeMode.light
        : ThemeMode.dark,
    builder: builder,
    home: home,
  );

  Widget builder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  );
}

Future<void> checkAccessibility(WidgetTester tester) async {
  await tester.pump();
  expect(
    tester.takeException(),
    isNull,
    reason: 'No layout or rendering errors',
  );
  try {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  } catch (_) {
    debugDumpSemanticsTree();
    rethrow;
  }
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  try {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  } catch (_) {
    debugDumpSemanticsTree();
    rethrow;
  }
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// Check overlapping viewports, including controls below the initial fold.
Future<void> checkScrollableAccessibility(WidgetTester tester) async {
  final scrollable = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 300));
  for (var page = 0; page < 100; page++) {
    await checkAccessibility(tester);
    if (position.pixels >= position.maxScrollExtent) return;
    position.jumpTo(
      (position.pixels + position.viewportDimension * .65).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('Screen did not reach its final controls within 100 viewports');
}

Future<void> pressTab(WidgetTester tester, {bool reverse = false}) async {
  if (reverse) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (reverse) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Traverse using actual keyboard events and verify the focused control is visible.
Future<void> focusByKeyboard(WidgetTester tester, Finder control) async {
  await reveal(tester, control);
  final element = control.evaluate().single;
  for (var step = 0; step < 80; step++) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context != null) {
      var ownsFocus = focus!.context == element;
      focus.context!.visitAncestorElements((ancestor) {
        if (ancestor == element) ownsFocus = true;
        return !ownsFocus;
      });
      if (ownsFocus) {
        expect(control.hitTestable(), findsOneWidget);
        return;
      }
    }
    await pressTab(tester);
  }
  fail('Keyboard traversal could not reach $control');
}

Future<void> unmount(
  WidgetTester tester,
  List<ChangeNotifier> controllers,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (final controller in controllers) {
    controller.dispose();
  }
}

void accessibilityTest(
  String name,
  AccessibilityScenario scenario,
  WidgetTesterCallback body,
) {
  testWidgets(name, (tester) async {
    final semantics = scenario.configure(tester);
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    }
  });
}

Future<void> reveal(WidgetTester tester, Finder control) async {
  final scrollable = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;
  if (control.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      control,
      200,
      scrollable: scrollable,
      maxScrolls: 100,
    );
  }
  await tester.ensureVisible(control);
  await tester.pump(const Duration(milliseconds: 300));
}

void expectKeyboardFocus(Finder control) {
  final target = control.evaluate().single;
  final context = FocusManager.instance.primaryFocus?.context;
  var ownsFocus = context == target;
  context?.visitAncestorElements((ancestor) {
    if (ancestor == target) ownsFocus = true;
    return !ownsFocus;
  });
  expect(
    ownsFocus,
    isTrue,
    reason: 'Keyboard focus should return to the owning action',
  );
  expect(control.hitTestable(), findsOneWidget);
  expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
}
