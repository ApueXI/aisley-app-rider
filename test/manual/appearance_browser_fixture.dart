// Synthetic appearance verification: no live API or real credentials.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:aisley_app/app/appearance/appearance_controller.dart';
import 'package:aisley_app/app/appearance/appearance_scope.dart';
import 'package:aisley_app/app/appearance/appearance_store.dart';
import 'package:aisley_app/app/courier_app.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

late SemanticsHandle semantics;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  final appearance = AppearanceController(
    store: DeviceAppearanceStore(),
    defaultMode: ThemeMode.system,
  );
  await appearance.restore();
  final auth =
      AuthController(authRepository: _Auth(), dashboardRepository: _Dashboard())
        ..status = AuthStatus.authenticated
        ..courier = CourierIdentity.fromJson(const {
          'id': 'courier-synthetic',
          'email': 'courier@example.invalid',
          'role': 'courier',
          'status': 'active',
          'profile': {'first_name': 'Maya', 'last_name': 'Santos'},
          'logistics': {
            'status': 'approved',
            'organization': 'AISLEY Express',
            'hub': 'Example Hub',
          },
        });
  runApp(
    AppearanceRoot(
      controller: appearance,
      child: CourierApp(authController: auth),
    ),
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
