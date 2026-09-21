/// Grouped student create/edit form (S05, S07).
///
/// Name is the only required personal field. Unanswered optional and religious
/// questions are preserved as null ("not informed"). A backend validation,
/// conflict or unavailable failure keeps the operator's in-memory values and
/// offers an explicit reload; success is announced only after the backend
/// acknowledges the mutation. Nothing is persisted locally.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/common.dart';
import '../../domain/ports.dart';
import '../../domain/student.dart';
import '../../domain/validation.dart';
import '../../ui/app_theme.dart';
import '../../ui/dirty_form_guard.dart';
import '../../ui/form_fields.dart';
import '../../ui/phone_formatter.dart';
import 'enrollment_history.dart';
import 'student_repository.dart';

class StudentFormConfig {
  const StudentFormConfig({
    required this.congregationId,
    this.studentId,
    this.expectedRevision,
    this.initial,
  });

  final String congregationId;
  final String? studentId;
  final int? expectedRevision;
  final Student? initial;

  bool get isEditing => studentId != null;
}

class StudentFormPage extends StatefulWidget {
  const StudentFormPage({
    super.key,
    required this.repository,
    required this.config,
    this.onSaved,
    this.onCancel,
    this.nowUtc,
  });

  final StudentRepository repository;
  final StudentFormConfig config;
  final ValueChanged<StudentMutationResult>? onSaved;
  final VoidCallback? onCancel;

  /// Test seam for the Recife "today" rule. Defaults to the real UTC now.
  final DateTime Function()? nowUtc;

  static const String invalidDateMessage =
      'Data inválida. Use o formato dd/MM/aaaa.';
  static const String birthDateHelper = 'Formato dd/MM/aaaa.';
  static const String baptismConflictMessage =
      'Quem já foi batizado não pode desejar o batismo.';

  static const Key nameFieldKey = Key('student-form-name');
  static const Key birthDateFieldKey = Key('student-form-birth-date');
  static const Key phoneFieldKey = Key('student-form-phone');
  static const Key educationFieldKey = Key('student-form-education');
  static const Key maritalStatusFieldKey = Key('student-form-marital-status');
  static const Key streetFieldKey = Key('student-form-street');
  static const Key districtFieldKey = Key('student-form-district');
  static const Key cityFieldKey = Key('student-form-city');
  static const Key postalCodeFieldKey = Key('student-form-postal-code');
  static const Key stateCodeFieldKey = Key('student-form-state');
  static const Key newConvertFieldKey = Key('student-form-new-convert');
  static const Key waterBaptizedFieldKey = Key('student-form-water-baptized');
  static const Key wantsBaptismFieldKey = Key('student-form-wants-baptism');
  static const Key saveKey = Key('student-form-save');
  static const Key cancelKey = Key('student-form-cancel');
  static const Key reloadKey = Key('student-form-reload');
  static const Key errorKey = Key('student-form-error');

  @override
  State<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<StudentFormPage> {
  final GlobalKey<AppFormState> _formKey = GlobalKey<AppFormState>();
  final DirtyFormGuard _guard = DirtyFormGuard();

  late final TextEditingController _name;
  late final TextEditingController _birthDate;
  late final TextEditingController _phone;
  late final TextEditingController _education;
  late final TextEditingController _maritalStatus;
  late final TextEditingController _street;
  late final TextEditingController _district;
  late final TextEditingController _city;
  late final TextEditingController _postalCode;
  late final TextEditingController _stateCode;
  late final List<TextEditingController> _controllers;

  bool? _newConvert;
  bool? _waterBaptized;
  bool? _wantsBaptism;
  int? _expectedRevision;
  AppFailure? _failure;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final Student? initial = widget.config.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _birthDate = TextEditingController(
      text: initial?.birthDate == null
          ? ''
          : formatBrazilianDate(initial!.birthDate!),
    );
    _phone = TextEditingController(text: formatPhone(initial?.phoneE164 ?? ''));
    _education = TextEditingController(text: initial?.education ?? '');
    _maritalStatus = TextEditingController(text: initial?.maritalStatus ?? '');
    _street = TextEditingController(text: initial?.address?.street ?? '');
    _district = TextEditingController(text: initial?.address?.district ?? '');
    _city = TextEditingController(text: initial?.address?.city ?? '');
    _postalCode = TextEditingController(
      text: initial?.address?.postalCode ?? '',
    );
    _stateCode = TextEditingController(text: initial?.address?.stateCode ?? '');
    _controllers = <TextEditingController>[
      _name,
      _birthDate,
      _phone,
      _education,
      _maritalStatus,
      _street,
      _district,
      _city,
      _postalCode,
      _stateCode,
    ];
    for (final TextEditingController controller in _controllers) {
      controller.addListener(_onChanged);
    }
    _newConvert = initial?.newConvert;
    _waterBaptized = initial?.waterBaptized;
    _wantsBaptism = initial?.wantsBaptism;
    _expectedRevision = widget.config.expectedRevision ?? initial?.revision;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.removeListener(_onChanged);
      controller.dispose();
    }
    _guard.dispose();
    super.dispose();
  }

  void _onChanged() => _guard.markDirty();

  DateTime _nowUtc() => widget.nowUtc?.call() ?? DateTime.now().toUtc();

  String? _validateBirthDate(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    final CalendarDate? parsed = parseBrazilianDateInput(raw);
    if (parsed == null) {
      return StudentFormPage.invalidDateMessage;
    }
    return validateBirthDate(parsed, nowUtc: _nowUtc());
  }

  String? _validatePostalCode(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    return RegExp(r'^\d{8}$').hasMatch(raw)
        ? null
        : 'O CEP deve ter exatamente 8 dígitos.';
  }

  String? _validateStateCode(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    return brazilianStateCodes.contains(raw.toUpperCase())
        ? null
        : 'UF inválida.';
  }

  String? _optionalTextOrNull(String raw) {
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Address? _address() {
    final String? street = _optionalTextOrNull(_street.text);
    final String? district = _optionalTextOrNull(_district.text);
    final String? city = _optionalTextOrNull(_city.text);
    final String? postalCode = _optionalTextOrNull(_postalCode.text);
    // The backend compares against uppercase UF codes only; normalize here so a
    // case-insensitive client value is not rejected server-side (S05).
    final String? stateCode = _optionalTextOrNull(_stateCode.text)
        ?.toUpperCase();
    if (street == null &&
        district == null &&
        city == null &&
        postalCode == null &&
        stateCode == null) {
      return null;
    }
    return Address(
      street: street,
      district: district,
      city: city,
      postalCode: postalCode,
      stateCode: stateCode,
    );
  }

  StudentDraft _draft(CalendarDate? birthDate) {
    final String phoneRaw = _phone.text.trim();
    return StudentDraft(
      name: _name.text,
      phone: phoneRaw.isEmpty ? null : normalizeBrazilianPhone(phoneRaw),
      birthDate: birthDate,
      address: _address(),
      education: _optionalTextOrNull(_education.text),
      maritalStatus: _optionalTextOrNull(_maritalStatus.text),
      newConvert: _newConvert,
      waterBaptized: _waterBaptized,
      wantsBaptism: _wantsBaptism,
    );
  }

  Future<void> _submit() async {
    final bool valid =
        _formKey.currentState?.validateAndFocusFirstError() ?? false;
    if (!valid) {
      return;
    }
    final String birthRaw = _birthDate.text.trim();
    final CalendarDate? birthDate = birthRaw.isEmpty
        ? null
        : parseBrazilianDateInput(birthRaw);
    final String? contradiction = validateBaptismAnswers(
      waterBaptized: _waterBaptized,
      wantsBaptism: _wantsBaptism,
    );
    if (contradiction != null) {
      setState(
        () => _failure = AppFailure(
          code: AppFailureCode.validation,
          message: contradiction,
        ),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final StudentMutationResult result = await widget.repository.saveStudent(
        draft: _draft(birthDate),
        congregationId: widget.config.congregationId,
        id: widget.config.studentId,
        expectedRevision: _expectedRevision,
      );
      if (!mounted) return;
      _guard.markClean();
      setState(() => _submitting = false);
      widget.onSaved?.call(result);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      // Inputs keep their in-memory values; no draft is persisted locally.
      setState(() {
        _submitting = false;
        _failure = failure;
      });
    }
  }

  /// Refreshes only the authoritative revision and clears the failure so the
  /// operator can resubmit the same in-memory values.
  Future<void> _reload() async {
    final String? id = widget.config.studentId;
    if (id == null) {
      setState(() => _failure = null);
      return;
    }
    try {
      final Student? student = await widget.repository.getStudent(
        id: id,
        congregationId: widget.config.congregationId,
      );
      if (!mounted) return;
      setState(() {
        if (student != null) {
          _expectedRevision = student.revision;
        }
        _failure = null;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    }
  }

  Future<void> _cancel() async {
    final bool leave = await _guard.confirmLeave(context);
    if (!leave || !mounted) {
      return;
    }
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final Widget form = AppForm(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _section(context, 'Dados pessoais'),
          AppTextField(
            key: StudentFormPage.nameFieldKey,
            label: 'Nome',
            controller: _name,
            required: true,
            validator: validateDisplayName,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.x3),
          AppDateField(
            key: StudentFormPage.birthDateFieldKey,
            label: 'Data de nascimento',
            controller: _birthDate,
            helperText: StudentFormPage.birthDateHelper,
            validator: _validateBirthDate,
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: StudentFormPage.educationFieldKey,
            label: 'Escolaridade',
            controller: _education,
            validator: (String? value) =>
                validateOptionalText(value, maxLength: optionalTextMaxLength),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: StudentFormPage.maritalStatusFieldKey,
            label: 'Estado civil',
            controller: _maritalStatus,
            validator: (String? value) =>
                validateOptionalText(value, maxLength: optionalTextMaxLength),
          ),
          _section(context, 'Contato'),
          AppTextField(
            key: StudentFormPage.phoneFieldKey,
            label: 'Telefone',
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: <TextInputFormatter>[PhoneInputFormatter()],
            helperText:
                'Compartilhado com a equipe autenticada quando informado.',
            validator: validatePhone,
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: StudentFormPage.streetFieldKey,
            label: 'Rua',
            controller: _street,
            validator: (String? value) =>
                validateOptionalText(value, maxLength: addressStreetMaxLength),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: StudentFormPage.districtFieldKey,
            label: 'Bairro',
            controller: _district,
            validator: (String? value) => validateOptionalText(
              value,
              maxLength: addressDistrictMaxLength,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: StudentFormPage.cityFieldKey,
            label: 'Cidade',
            controller: _city,
            validator: (String? value) =>
                validateOptionalText(value, maxLength: addressCityMaxLength),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: StudentFormPage.postalCodeFieldKey,
            label: 'CEP',
            controller: _postalCode,
            keyboardType: TextInputType.number,
            validator: _validatePostalCode,
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: StudentFormPage.stateCodeFieldKey,
            label: 'UF',
            controller: _stateCode,
            helperText: 'Sigla com duas letras.',
            validator: _validateStateCode,
          ),
          _section(context, 'Discipulado'),
          _booleanField(
            key: StudentFormPage.newConvertFieldKey,
            label: 'Novo convertido',
            value: _newConvert,
            onChanged: (bool? value) => setState(() {
              _newConvert = value;
              _guard.markDirty();
            }),
          ),
          const SizedBox(height: AppSpacing.x3),
          _booleanField(
            key: StudentFormPage.waterBaptizedFieldKey,
            label: 'Batizado nas águas',
            value: _waterBaptized,
            onChanged: (bool? value) => setState(() {
              _waterBaptized = value;
              _guard.markDirty();
            }),
          ),
          const SizedBox(height: AppSpacing.x3),
          _booleanField(
            key: StudentFormPage.wantsBaptismFieldKey,
            label: 'Deseja o batismo',
            value: _wantsBaptism,
            onChanged: (bool? value) => setState(() {
              _wantsBaptism = value;
              _guard.markDirty();
            }),
          ),
          if (_failure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x4),
            Text(
              _failure!.message,
              key: StudentFormPage.errorKey,
              style: TextStyle(color: tokens.error),
            ),
            const SizedBox(height: AppSpacing.x2),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                key: StudentFormPage.reloadKey,
                label: 'Recarregar',
                variant: AppButtonVariant.secondary,
                onPressed: _reload,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (widget.onCancel != null)
                AppButton(
                  key: StudentFormPage.cancelKey,
                  label: 'Cancelar',
                  variant: AppButtonVariant.text,
                  onPressed: _cancel,
                ),
              const SizedBox(width: AppSpacing.x2),
              AppButton(
                key: StudentFormPage.saveKey,
                label: 'Salvar',
                isSubmitting: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
      },
      child: _guard.wrap(
        context,
        child: AppFormScrollView(child: form),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.x6, bottom: AppSpacing.x3),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _booleanField({
    required Key key,
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) => DropdownButtonFormField<bool?>(
    key: key,
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: const <DropdownMenuItem<bool?>>[
      DropdownMenuItem<bool?>(child: Text('Não informado')),
      DropdownMenuItem<bool?>(value: true, child: Text('Sim')),
      DropdownMenuItem<bool?>(value: false, child: Text('Não')),
    ],
    onChanged: _submitting ? null : onChanged,
  );
}
