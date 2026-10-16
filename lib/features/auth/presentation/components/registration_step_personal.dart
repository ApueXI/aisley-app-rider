part of '../registration_screen.dart';

extension _RegistrationPersonalStep on _RegistrationScreenState {
  Widget _buildPersonalStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeading(
        context,
        'Personal details',
        'Use the same legal details shown on your identity document.',
      ),
      _twoColumn(
        _textField(
          controller: _firstNameController,
          label: 'First name',
          icon: Icons.person_outline,
          validator: (value) => _required(value, 'Enter your first name.'),
          serverKey: 'first_name',
        ),
        _textField(
          controller: _lastNameController,
          label: 'Last name',
          icon: Icons.person_outline,
          validator: (value) => _required(value, 'Enter your last name.'),
          serverKey: 'last_name',
        ),
      ),
      const SizedBox(height: 12),
      _textField(
        controller: _middleNameController,
        label: 'Middle initial (optional)',
        icon: Icons.person_outline,
        maxLength: 1,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(1),
        ],
        serverKey: 'middle_name',
      ),
      const SizedBox(height: 12),
      _twoColumn(
        DropdownButtonFormField<String>(
          key: _fieldNavigation.fieldKey('sex'),
          focusNode: _fieldNavigation.focusNode('sex'),
          initialValue: _sex,
          isExpanded: true,
          itemHeight: null,
          decoration: _decoration(
            'Sex',
            icon: Icons.wc_outlined,
            errorText: _serverError('sex'),
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'non_binary', child: Text('Non-binary')),
            DropdownMenuItem(
              value: 'prefer_not_to_say',
              child: Text('Prefer not to say'),
            ),
          ],
          onChanged: _isSubmitting
              ? null
              : (value) => _updateState(() => _sex = value),
          validator: (value) => value == null ? 'Select your sex.' : null,
        ),
        TextFormField(
          key: _fieldNavigation.fieldKey('contact_number'),
          focusNode: _fieldNavigation.focusNode('contact_number'),
          controller: _contactNumberController,
          enabled: !_isSubmitting,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          maxLength: 32,
          decoration: _decoration(
            'Contact number',
            hint: '09XX XXX XXXX',
            icon: Icons.phone_outlined,
            errorText: _serverError('contact_number'),
          ),
          validator: (value) => _required(value, 'Enter your contact number.'),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: _fieldNavigation.fieldKey('birth_date'),
        focusNode: _fieldNavigation.focusNode('birth_date'),
        controller: _birthDateController,
        enabled: !_isSubmitting,
        readOnly: true,
        textInputAction: TextInputAction.next,
        onTap: _isSubmitting ? null : _pickBirthDate,
        decoration: _decoration(
          'Birth date',
          hint: 'YYYY-MM-DD',
          icon: Icons.calendar_today_outlined,
          errorText: _serverError('birth_date'),
          suffixIcon: IconButton(
            tooltip: 'Select birth date',
            onPressed: _isSubmitting ? null : _pickBirthDate,
            icon: const Icon(Icons.calendar_today_outlined),
          ),
        ),
        validator: (_) => _birthDate == null ? 'Select your birth date.' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: _fieldNavigation.fieldKey('email'),
        focusNode: _fieldNavigation.focusNode('email'),
        controller: _emailController,
        readOnly: true,
        enabled: !_isSubmitting,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const <String>[AutofillHints.email],
        decoration: _decoration(
          'Email',
          hint: 'you@example.com',
          icon: Icons.mail_outline,
          errorText: _serverError('email'),
        ),
        validator: _validateEmail,
      ),
      const SizedBox(height: 12),
    ],
  );
}
