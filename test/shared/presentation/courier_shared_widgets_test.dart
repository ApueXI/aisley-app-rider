import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/shared/presentation/courier_section_header.dart';
import 'package:aisley_app/shared/presentation/courier_status_badge.dart';
import 'package:aisley_app/shared/presentation/courier_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('surface card exposes its tap action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCourierTheme(Brightness.light),
        home: Scaffold(
          body: CourierSurfaceCard(
            onTap: () => taps++,
            child: const Text('Open work'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open work'));

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section header stacks its trailing content at 320px and 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCourierTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: CourierSectionHeader(
              title: 'Available work',
              subtitle: 'Current items from your work lists',
              trailing: Text('Last refreshed 9:45 AM'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available work'), findsOneWidget);
    expect(find.text('Last refreshed 9:45 AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status badge exposes its label once and uses success tokens', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final theme = buildCourierTheme(Brightness.light);
    final success = theme.extension<CourierThemeTokens>()!;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: CourierStatusBadge(
            label: 'Affiliation approved',
            tone: CourierStatusTone.success,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Affiliation approved'), findsOneWidget);
    final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, success.successBackground);
    expect(decoration.border!.top.color, success.successBorder);
    semantics.dispose();
  });
}
