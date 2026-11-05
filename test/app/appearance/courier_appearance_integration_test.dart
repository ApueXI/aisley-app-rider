import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/app/courier_app.dart';
import 'package:aisley_app/app/appearance/appearance_controller.dart';
import 'package:aisley_app/app/appearance/appearance_scope.dart';
import 'package:aisley_app/app/appearance/appearance_tile.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

import 'appearance_controller_test.dart' show MemoryAppearanceStore;

void main() {
  testWidgets(
    'Courier Account offers appearance and retains it through sign out',
    (tester) async {
      final auth =
          AuthController(
              authRepository: _Auth(),
              dashboardRepository: _Dashboard(),
            )
            ..status = AuthStatus.authenticated
            ..courier = CourierIdentity.fromJson(const {
              'id': 'courier-1',
              'email': 'courier@example.com',
              'role': 'courier',
              'status': 'active',
              'profile': {'first_name': 'Maya', 'last_name': 'Santos'},
              'logistics': {
                'status': 'approved',
                'organization': 'Aisley Express',
                'hub': 'Makati Hub',
              },
            });
      final appearance = AppearanceController(
        store: MemoryAppearanceStore(),
        defaultMode: ThemeMode.system,
      );
      await tester.pumpWidget(
        AppearanceRoot(
          controller: appearance,
          child: CourierApp(authController: auth),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Appearance').hitTestable(),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('account-menu')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        Theme.of(tester.element(find.byType(AppearanceTile))).brightness,
        Brightness.dark,
      );
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceTile), findsNothing);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
}

class _Auth implements AuthRepository {
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Dashboard implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async => DashboardSnapshot(
    sections: const {},
    freshness: const DashboardFreshness(
      state: DashboardFreshnessState.scaffold,
    ),
  );
}
