part of '../registration_screen.dart';

extension _RegistrationLogisticsStep on _RegistrationScreenState {
  Widget _buildLogisticsStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeading(
        context,
        'Logistics affiliation',
        'Choose the Logistics organization to review your application.',
      ),
      KeyedSubtree(
        key: _fieldNavigation.anchorKey('logistics_organization_id'),
        child: _buildOrganizationField(context),
      ),
      const SizedBox(height: 24),
      _sectionHeading(
        context,
        'Vehicle',
        'Enter the vehicle you will use for Courier work.',
      ),
      _twoColumn(
        KeyedSubtree(
          key: ValueKey<String?>('vehicle-$_vehicleType'),
          child: DropdownButtonFormField<String>(
            key: _fieldNavigation.fieldKey('vehicle_type'),
            focusNode: _fieldNavigation.focusNode('vehicle_type'),
            initialValue: _vehicleType,
            isExpanded: true,
            itemHeight: null,
            decoration: _decoration(
              'Vehicle type',
              icon: Icons.two_wheeler_outlined,
              errorText: _serverError('vehicle_type'),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'motorcycle', child: Text('Motorcycle')),
              DropdownMenuItem(value: 'car', child: Text('Car')),
              DropdownMenuItem(value: 'van', child: Text('Van')),
              DropdownMenuItem(value: 'truck', child: Text('Truck')),
            ],
            onChanged: _isSubmitting
                ? null
                : (value) => _updateState(() => _vehicleType = value),
            validator: (value) =>
                value == null ? 'Select a vehicle type.' : null,
          ),
        ),
        _textField(
          controller: _plateNumberController,
          label: 'Plate number',
          icon: Icons.confirmation_number_outlined,
          maxLength: 64,
          validator: (value) => _required(value, 'Enter your plate number.'),
          serverKey: 'plate_number',
          textInputAction: TextInputAction.done,
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}
