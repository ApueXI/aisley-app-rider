part of '../registration_screen.dart';

extension _RegistrationEvidenceStep on _RegistrationScreenState {
  Widget _buildEvidenceStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeading(
        context,
        'Required evidence',
        'JPEG, PNG or WebP images, each smaller than 10 MiB. Your evidence stays private.',
      ),
      _evidencePicker(
        context,
        label: 'Government ID / driver’s license',
        fieldKey: 'government_id',
        upload: _governmentId,
        onPick: () => _pickEvidence(governmentId: true),
        onRemove: () => _updateState(() => _governmentId = null),
      ),
      const SizedBox(height: 12),
      _evidencePicker(
        context,
        label: 'Vehicle registration (OR/CR)',
        fieldKey: 'vehicle_registration',
        upload: _vehicleRegistration,
        onPick: () => _pickEvidence(governmentId: false),
        onRemove: () => _updateState(() => _vehicleRegistration = null),
      ),
      const SizedBox(height: 26),
    ],
  );
}
