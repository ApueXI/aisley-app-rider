import 'dart:convert';
import 'dart:typed_data';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Synthetic responses from Courier Auth v2.6, copied checkout 4c3f504.
// Condition labels describe upstream scenarios, not extra wire fields or a
// simulated backend. These tests verify response consumption, not enforcement.
class AuthDenialFixture {
  const AuthDenialFixture(this.code, this.message, this.status);

  final String code;
  final String message;
  final AuthStatus status;

  http.Response response() =>
      http.Response(jsonEncode({'code': code, 'message': message}), 403);
}

const accountDenials = [
  AuthDenialFixture(
    'ACCOUNT_PENDING_APPROVAL',
    'This Courier account is not active.',
    AuthStatus.pendingApproval,
  ),
  AuthDenialFixture(
    'ACCOUNT_REJECTED',
    'This Courier account is not active.',
    AuthStatus.rejected,
  ),
  AuthDenialFixture(
    'ACCOUNT_SUSPENDED',
    'This Courier account is not active.',
    AuthStatus.suspendedOrDeactivated,
  ),
  AuthDenialFixture(
    'ACCOUNT_INACTIVE',
    'This Courier account is not active.',
    AuthStatus.suspendedOrDeactivated,
  ),
];
const affiliationDenial = AuthDenialFixture(
  'LOGISTICS_ASSOCIATION_INVALID',
  'This Courier is not approved by an active Logistics organization.',
  AuthStatus.invalidAffiliation,
);
const wrongRoleDenial = AuthDenialFixture(
  'FORBIDDEN_ROLE',
  'This area is restricted to couriers.',
  AuthStatus.accessDenied,
);
const invalidAffiliationConditions = [
  'missing affiliation',
  'pending affiliation',
  'rejected affiliation',
  'revoked affiliation',
  'inactive Logistics owner',
  'missing Logistics owner',
  'missing hub',
];
const duplicateEmailMessage =
    'A Courier account with this email already exists.';
http.Response duplicateEmailResponse() => http.Response(
  jsonEncode({
    'code': 'EMAIL_ALREADY_REGISTERED',
    'message': duplicateEmailMessage,
    'errors': {
      'email': [duplicateEmailMessage],
    },
  }),
  422,
);
http.Response unauthorizedResponse() => http.Response('{}', 401);
http.Response policyRequiredResponse() => http.Response(
  jsonEncode({
    'code': 'POLICY_CONSENT_REQUIRED',
    'message': 'Current policy consent is required.',
  }),
  403,
);
http.Response identityResponse() =>
    http.Response(jsonEncode({'courier': courierJson}), 200);
http.Response loginResponse() => http.Response(
  jsonEncode({'token': 'synthetic-test-token', 'courier': courierJson}),
  200,
);

const courierJson = {
  'id': 'courier-test',
  'email': 'courier@example.test',
  'role': 'courier',
  'status': 'active',
  'profile': {'first_name': 'Test', 'last_name': 'Courier'},
  'logistics': {
    'status': 'approved',
    'organization': 'Test Logistics',
    'hub': 'Test Hub',
  },
};

class AuthTestStorage implements TokenStorage {
  String? token;
  String? failOperation;
  int writes = 0;
  int clears = 0;

  void _check(String operation) {
    if (failOperation == operation) {
      throw TokenStorageException(
        operation,
        StateError('private storage detail'),
      );
    }
  }

  @override
  Future<String?> read() async {
    _check('read');
    return token;
  }

  @override
  Future<void> write(String value) async {
    _check('write');
    writes++;
    token = value;
  }

  @override
  Future<void> clear() async {
    _check('clear');
    clears++;
    token = null;
  }
}

class AuthTestApi {
  AuthTestApi({Duration timeout = const Duration(seconds: 20)}) {
    client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      requestTimeout: timeout,
      client: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
    repository = ApiAuthRepository(client: client, tokenStorage: storage);
  }

  final storage = AuthTestStorage();
  final requests = <http.Request>[];
  Future<http.Response> Function(http.Request) respond = (_) async =>
      identityResponse();
  late final ApiClient client;
  late final ApiAuthRepository repository;
  AuthController controller({VoidSessionCallback? onSessionEnded}) =>
      AuthController(
        authRepository: repository,
        dashboardRepository: TestDashboardRepository(),
        onSessionEnded: onSessionEnded,
      );
}

typedef VoidSessionCallback = void Function();

class TestDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async =>
      DashboardSnapshot.fromScaffoldResponse({
        'data': <dynamic>[],
        'meta': {'next_cursor': null, 'generated_at': 'now'},
        'sections': {
          for (final name in [
            'notifications',
            'available_tasks',
            'active_tasks',
          ])
            name: {
              'state': 'unavailable',
              'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
            },
        },
        'freshness': {
          'state': 'scaffold',
          'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
          'generated_at': 'now',
        },
      });
}

CourierRegistrationRequest registrationRequest() {
  final image = RegistrationUpload(
    path: '',
    fileName: 'test.png',
    bytes: Uint8List.fromList([137, 80, 78, 71]),
  );
  return CourierRegistrationRequest(
    firstName: 'Test',
    lastName: 'Courier',
    contactNumber: '09171234567',
    sex: 'female',
    birthDate: DateTime(1998, 1, 1),
    email: 'courier@example.test',
    password: 'Synthetic123',
    passwordConfirmation: 'Synthetic123',
    logisticsOrganizationId: 'organization-test',
    vehicleType: 'truck',
    plateNumber: 'TEST-123',
    addressLine1: 'Test street',
    barangay: 'Test barangay',
    cityMunicipality: 'Test city',
    province: 'Test province',
    region: 'Test region',
    postalCode: '0123',
    governmentId: image,
    vehicleRegistration: image,
  );
}
