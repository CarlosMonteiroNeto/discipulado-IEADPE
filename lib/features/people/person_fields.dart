import 'package:flutter/material.dart';

import '../../ui/br_input.dart';
import '../../ui/form_fields.dart';

/// Shared input controls for the canonical person identity.
///
/// The owner supplies controllers so the same fields can be embedded in convert
/// and student forms without either screen owning a second identity model.
class PersonFields extends StatelessWidget {
  const PersonFields({
    super.key,
    required this.name,
    required this.phone,
    required this.birthDate,
    required this.street,
    required this.district,
    required this.city,
    required this.postalCode,
    required this.stateCode,
    this.enabled = true,
    this.nameValidator,
    this.birthDateValidator,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController birthDate;
  final TextEditingController street;
  final TextEditingController district;
  final TextEditingController city;
  final TextEditingController postalCode;
  final TextEditingController stateCode;
  final bool enabled;
  final String? Function(String?)? nameValidator;
  final String? Function(String?)? birthDateValidator;

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AppTextFormField(
      fieldKey: ValueKey(key),
      controller: controller,
      label: label,
      enabled: enabled,
      keyboardType: keyboard,
      validator: validator,
      maxLength: maxLength,
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      _field('person-name', 'Nome *', name, validator: nameValidator),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: BrPhoneField(
          fieldKey: const ValueKey('person-phone'),
          controller: phone,
          enabled: enabled,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: BrDateField(
          fieldKey: const ValueKey('person-birth-date'),
          controller: birthDate,
          label: 'Data de nascimento',
          enabled: enabled,
          allowClear: true,
          validator:
              birthDateValidator ?? (value) => brDateValidationError(value),
        ),
      ),
      _field('person-address-street', 'Logradouro', street),
      _field('person-address-district', 'Bairro', district),
      _field('person-address-city', 'Cidade', city),
      _field(
        'person-address-postal-code',
        'CEP',
        postalCode,
        keyboard: TextInputType.number,
      ),
      _field('person-address-state-code', 'UF', stateCode, maxLength: 2),
    ],
  );
}
