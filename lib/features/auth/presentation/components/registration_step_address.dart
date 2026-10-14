part of '../registration_screen.dart';

extension _RegistrationAddressStep on _RegistrationScreenState {
  Widget _buildAddressStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeading(
        context,
        'Address',
        'Select your address or use manual entry. No map pin is required.',
      ),
      _textField(
        controller: _addressLine1Controller,
        label: 'Street / house detail',
        icon: Icons.home_outlined,
        validator: (value) =>
            _required(value, 'Enter your street or house detail.'),
        serverKey: 'address.address_line_1',
      ),
      const SizedBox(height: 12),
      _textField(
        controller: _addressLine2Controller,
        label: 'Address line 2 (optional)',
        icon: Icons.add_home_outlined,
        serverKey: 'address.address_line_2',
      ),
      const SizedBox(height: 12),
      _buildAddressDirectory(context),
      const SizedBox(height: 12),
      _textField(
        controller: _postalCodeController,
        label: 'Postal code',
        keyboardType: TextInputType.number,
        maxLength: 10,
        validator: (value) => _required(value, 'Enter your postal code.'),
        serverKey: 'address.postal_code',
      ),
      const SizedBox(height: 24),
    ],
  );
}
