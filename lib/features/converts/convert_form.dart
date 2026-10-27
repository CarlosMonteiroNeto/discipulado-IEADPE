import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../domain/worship_types.dart';
import '../../data/supabase_gateway.dart';
import '../../ui/br_input.dart';
import '../../ui/form_fields.dart';
import '../../ui/unified_theme.dart';

/// Only user-editable fields. Never serialize a read DTO into a command.
class ConvertDraft {
  const ConvertDraft({
    required this.name,
    required this.landmark,
    required this.gender,
    required this.conversionDate,
    required this.worshipType,
    this.address,
    this.phone,
    this.birthDate,
    this.personAddress,
    this.preserveNullAddress = false,
    this.congregationId,
    this.age,
    this.photoBytes,
    this.removePhoto = false,
  });
  final String name, landmark;
  final String? worshipType;
  final Gender gender;
  final DateOnly conversionDate;
  final String? address, phone, congregationId;
  final DateOnly? birthDate;
  final Map<String, Object?>? personAddress;
  final bool preserveNullAddress;
  final int? age;
  final Uint8List? photoBytes;
  final bool removePhoto;
  Map<String, Object?> payload() => {
    'congregation_id': congregationId,
    'person': {
      'name': name,
      'phone': phone,
      'birth_date': birthDate?.toString(),
      'address': preserveNullAddress
          ? null
          : personAddress ??
                {
                  'street': address,
                  'district': null,
                  'city': null,
                  'postal_code': null,
                  'state_code': null,
                },
    },
    'convert': {
      'landmark': landmark,
      'gender': gender.wireValue,
      'conversion_date': conversionDate.toString(),
      'worship_type': worshipType,
      'age': age,
      'photo_asset_id': null,
    },
  };
}

Future<Uint8List?> pickConvertPhoto() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return null;
  if (await file.length() > 20 * 1024 * 1024) {
    throw const DataFailure('invalid');
  }
  return file.readAsBytes();
}

class ConvertForm extends StatefulWidget {
  const ConvertForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.congregations = const [],
    this.onCancel,
    this.gateway,
    this.pickPhoto = pickConvertPhoto,
    this.existingPhoto,
    this.now = DateTime.now,
  });
  final ConvertRecord? initial;
  final Future<void> Function(ConvertDraft) onSubmit;
  final List<Congregation> congregations;
  final VoidCallback? onCancel;
  final Gateway? gateway;
  final Future<Uint8List?> Function() pickPhoto;
  final Uint8List? existingPhoto;
  final DateTime Function() now;
  @override
  State<ConvertForm> createState() => _ConvertFormState();
}

class _ConvertFormState extends State<ConvertForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _address,
      _landmark,
      _phone,
      _age,
      _date;
  String? _congregation, _worship;
  Gender? _gender;
  Uint8List? _photo;
  bool _removePhoto = false, _busy = false, _picking = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final identity = i?.personIdentity;
    final identityAddress = identity?.address;
    _name = TextEditingController(text: identity?.name ?? i?.name);
    _address = TextEditingController(
      text: identity == null
          ? (i?.legacyIdentity?.address ?? i?.address)
          : identityAddress?['street'] as String?,
    );
    _landmark = TextEditingController(text: i?.landmark);
    _phone = TextEditingController(
      text: brPhoneDisplay(
        identity?.phone ?? i?.legacyIdentity?.phone ?? i?.phone,
      ),
    );
    _age = TextEditingController(text: i?.age?.toString());
    _date = TextEditingController(
      text: brDateDisplay(
        (i?.conversionDate ?? BusinessCalendar().today(widget.now()))
            .toString(),
      ),
    );
    _congregation = i?.congregationId;
    _worship = i?.worshipType;
    _gender = i?.gender;
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _landmark, _phone, _age, _date]) {
      c.clear();
      c.dispose();
    }
    _photo = null;
    super.dispose();
  }

  bool _current(String? token) {
    if (!mounted) return false;
    try {
      if (token != null) widget.gateway!.ensureCurrent(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pick() async {
    if (_picking || _busy) return;
    final token = widget.gateway?.context;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final bytes = await widget.pickPhoto();
      if (!_current(token)) return;
      if (bytes != null) {
        if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
          throw const DataFailure('invalid');
        }
        setState(() {
          _photo = Uint8List.fromList(bytes);
          _removePhoto = false;
        });
      }
    } catch (_) {
      if (_current(token)) {
        setState(
          () => _error = 'Não foi possível abrir a foto. Escolha outra imagem.',
        );
      }
    } finally {
      if (_current(token)) setState(() => _picking = false);
    }
  }

  DateOnly? _parsedDate() {
    final date = parseDateInput(_date.text);
    return date == null ? null : DateOnly(date.year, date.month, date.day);
  }

  Future<void> _submit() async {
    if (_busy || _picking || !_form.currentState!.validate()) return;
    final token = widget.gateway?.context;
    final i = widget.initial;
    String? optional(TextEditingController c, String? old) =>
        c.text == (old ?? '')
        ? old
        : (c.text.trim().isEmpty ? null : c.text.trim());
    final oldPerson = i?.personIdentity;
    final oldAddress = oldPerson?.address;
    final oldName = oldPerson?.name ?? i?.name;
    final oldAddressStreet = oldPerson == null
        ? i?.legacyIdentity?.address ?? i?.address
        : oldAddress?['street'] as String?;
    final preserveNullAddress =
        oldPerson != null && oldAddress == null && _address.text.trim().isEmpty;
    final street = optional(_address, oldAddressStreet);
    final personAddress = oldAddress == null
        ? {
            'street': street,
            'district': null,
            'city': null,
            'postal_code': null,
            'state_code': null,
          }
        : {...oldAddress, 'street': street};
    final name = _name.text == oldName ? oldName! : _name.text.trim();
    final draft = ConvertDraft(
      name: name,
      landmark: _landmark.text.trim(),
      gender: _gender!,
      conversionDate: _parsedDate()!,
      worshipType: _worship,
      address: optional(_address, oldAddressStreet),
      phone: resolveBrPhone(_phone.text),
      birthDate: oldPerson?.birthDate,
      personAddress: personAddress,
      preserveNullAddress: preserveNullAddress,
      congregationId: _congregation,
      age: _age.text.isEmpty ? null : int.parse(_age.text),
      photoBytes: _photo == null ? null : Uint8List.fromList(_photo!),
      removePhoto: _removePhoto,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(draft);
    } catch (error) {
      if (_current(token)) {
        setState(
          () => _error = error is DataFailure && error.code == 'permission'
              ? 'Seu acesso mudou. Volte e atualize a página.'
              : error is DataFailure && error.code == 'photo_upload'
              ? 'Não foi possível enviar a foto. Seus dados foram mantidos. Tente novamente.'
              : 'Não foi possível salvar. Seus dados foram mantidos. Tente novamente.',
        );
      }
    } finally {
      if (_current(token)) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label,
    TextEditingController c, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AppTextFormField(
      fieldKey: ValueKey(key),
      controller: c,
      readOnly: _busy,
      keyboardType: keyboard,
      validator: validator,
      onChanged: (_) => setState(() {}),
      label: label,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final old = widget.existingPhoto;
    // Keep the attached photo visible during replacement, until the page publishes success.
    final displayed = old ?? (_removePhoto ? null : _photo);
    final worships = {...worshipTypes, ?_worship};
    final congregations = {for (final c in widget.congregations) c.id: c.name};
    if (_congregation != null) {
      congregations.putIfAbsent(_congregation!, () => 'Congregação anterior');
    }
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: displayed == null
                      ? 'Sem foto do convertido'
                      : 'Foto do convertido',
                  child: Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: UnifiedColors.border,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x140f172a),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: displayed == null
                            ? const ColoredBox(
                                color: UnifiedColors.pageTint,
                                child: Icon(
                                  Icons.person_outline,
                                  size: 52,
                                  color: UnifiedColors.muted,
                                ),
                              )
                            : Image.memory(
                                displayed,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, s) => const ColoredBox(
                                  color: UnifiedColors.pageTint,
                                  child: Icon(
                                    Icons.person_outline,
                                    size: 52,
                                    color: UnifiedColors.muted,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _busy || _picking ? null : _pick,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(_picking ? 'Abrindo foto…' : 'Escolher foto'),
                    ),
                    if (_photo != null ||
                        old != null ||
                        widget.initial?.photoAssetId != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _photo = null;
                                _removePhoto = true;
                              }),
                        child: const Text('Remover foto'),
                      ),
                  ],
                ),
                if (_photo != null && old != null)
                  const Text(
                    'Nova foto selecionada. A foto atual será mantida até salvar.',
                  ),
                if (_removePhoto) const Text('A foto será removida ao salvar.'),
                DropdownButtonFormField<String>(
                  initialValue: _congregation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Congregação *',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    for (final c in congregations.entries)
                      DropdownMenuItem(value: c.key, child: Text(c.value)),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _congregation = v),
                  validator: (v) =>
                      v == null ? 'Selecione uma congregação' : null,
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  fieldKey: const ValueKey('person-name'),
                  controller: _name,
                  readOnly: _busy,
                  label: 'Nome *',
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Nome é obrigatório';
                    final inherited = widget.initial?.personIdentity?.name;
                    if (value != inherited && name.length > 200) {
                      return 'Reduza o nome para até 200 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                BrPhoneField(
                  fieldKey: const ValueKey('person-phone'),
                  controller: _phone,
                  enabled: !_busy,
                ),
                _field('person-address-street', 'Endereço', _address),
                _field(
                  'landmark',
                  'Ponto de referência *',
                  _landmark,
                  validator: (v) => v!.trim().isEmpty
                      ? 'Ponto de referência é obrigatório'
                      : null,
                ),
                _field(
                  'age',
                  'Idade',
                  _age,
                  keyboard: TextInputType.number,
                  validator: (v) => v!.isEmpty
                      ? null
                      : (int.tryParse(v) == null ||
                                int.parse(v) < 0 ||
                                int.parse(v) > 150
                            ? 'Informe uma idade entre 0 e 150'
                            : null),
                ),
                DropdownButtonFormField<Gender>(
                  initialValue: _gender,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Gênero *'),
                  items: const [
                    DropdownMenuItem(
                      value: Gender.male,
                      child: Text('Masculino'),
                    ),
                    DropdownMenuItem(
                      value: Gender.female,
                      child: Text('Feminino'),
                    ),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _gender = v),
                  validator: (v) => v == null ? 'Gênero é obrigatório' : null,
                ),
                const SizedBox(height: 16),
                BrDateField(
                  fieldKey: const ValueKey('conversion_date'),
                  controller: _date,
                  label: 'Data de conversão *',
                  enabled: !_busy,
                  validator: (value) {
                    final invalid = brDateValidationError(
                      value,
                      required: true,
                    );
                    if (invalid != null) return invalid;
                    final date = _parsedDate();
                    if (date == null) return 'Informe uma data válida.';
                    return date.compareTo(
                              BusinessCalendar().today(widget.now()),
                            ) >
                            0
                        ? 'A data não pode ser futura'
                        : null;
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _worship,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo de culto'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Não informado'),
                    ),
                    for (final w in worships)
                      DropdownMenuItem(value: w, child: Text(w)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _worship = v),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(liveRegion: true, child: Text(_error!)),
                  ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : widget.onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || _picking ? null : _submit,
                      icon: Icon(
                        _busy ? Icons.hourglass_top : Icons.save_outlined,
                      ),
                      label: Text(
                        _busy
                            ? 'Salvando…'
                            : widget.initial == null
                            ? 'Cadastrar'
                            : 'Atualizar',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
