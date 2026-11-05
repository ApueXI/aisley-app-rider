import '../../../core/networking/api_contract_exception.dart';
import 'policy_models.dart';

class PolicyBatchAcceptance {
  const PolicyBatchAcceptance({
    required this.acceptances,
    required this.status,
  });
  final List<PolicyAcceptance> acceptances;
  final PolicyConsentStatus status;

  factory PolicyBatchAcceptance.fromJson(Map<String, dynamic> json) {
    final rows = json['acceptances'];
    final status = json['status'];
    if (rows is! List || status is! Map || rows.any((row) => row is! Map)) {
      throw const ApiContractException('policy.batch.response');
    }
    final parsed = PolicyConsentStatus.fromJson(
      Map<String, dynamic>.from(status),
    );
    if (parsed.allRequiredAccepted &&
        parsed.policies.any((item) => item.required)) {
      throw const ApiContractException('policy.batch.status');
    }
    return PolicyBatchAcceptance(
      acceptances: rows
          .map(
            (row) => PolicyAcceptance.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
      status: parsed,
    );
  }
}
