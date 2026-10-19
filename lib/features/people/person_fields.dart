import 'package:flutter/material.dart';

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
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: enabled,
      keyboardType: keyboard,
      validator: validator,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      _field('person-name', 'Nome *', name, validator: nameValidator),
      _field(
        'person-phone',
        'Telefone (opcional)',
        phone,
        keyboard: TextInputType.phone,
      ),
      _field(
        'person-birth-date',
        'Data de nascimento (aaaa-mm-dd)',
        birthDate,
        keyboard: TextInputType.datetime,
        validator: birthDateValidator,
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
