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
import '../people/person_fields.dart';
import '../photos/photo_crop.dart';
import '../photos/photo_crop_page.dart';
import '../photos/photo_picker.dart';

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
    this.photoCrop,
    this.removePhoto = false,
  });
  final String name, landmark, worshipType;
  final Gender gender;
  final DateOnly conversionDate;
  final String? address, phone, congregationId;
  final DateOnly? birthDate;
  final Map<String, Object?>? personAddress;
  final bool preserveNullAddress;
  final int? age;
  final Uint8List? photoBytes;
  final NormalizedPhotoCrop? photoCrop;
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
  return pickProfilePhoto(ImageSource.gallery);
}

class ConvertForm extends StatefulWidget {
  const ConvertForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.congregations = const [],
    this.onCancel,
    this.gateway,
    this.pickPhoto,
    this.acquirePhoto = pickProfilePhoto,
    this.choosePhotoSource = chooseProfilePhotoSource,
    this.cropPhoto = showPhotoCrop,
    this.existingPhoto,
    this.now = DateTime.now,
    this.allowPhotos = false,
    this.allowCongregationChange = true,
    this.requireCongregation = true,
    this.submitLabel,
    this.photoAuthority,
    this.submissionLocked = false,
    this.submitEnabled = true,
    this.onPhotoAuthorityRevoked,
    this.revalidatePhotoAuthority,
    this.onCongregationChanged,
  });
  final ConvertRecord? initial;
  final Future<void> Function(ConvertDraft) onSubmit;
  final List<Congregation> congregations;
  final VoidCallback? onCancel;
  final Gateway? gateway;

  /// Legacy injectable hook retained for existing form tests/callers.
  final Future<Uint8List?> Function()? pickPhoto;
  final Future<Uint8List?> Function(ImageSource source) acquirePhoto;
  final Future<ImageSource?> Function(BuildContext context) choosePhotoSource;
  final Future<NormalizedPhotoCrop?> Function(
    BuildContext context,
    Uint8List source,
  )
  cropPhoto;
  final Uint8List? existingPhoto;
  final DateTime Function() now;
  final bool allowPhotos;
  final bool allowCongregationChange;
  final bool requireCongregation;
  final String? submitLabel;
  final bool Function(String? congregationId)? photoAuthority;
  final bool submissionLocked;
  final bool submitEnabled;
  final VoidCallback? onPhotoAuthorityRevoked;
  final Future<bool> Function(String? congregationId)? revalidatePhotoAuthority;
  final ValueChanged<String?>? onCongregationChanged;
  @override
  State<ConvertForm> createState() => _ConvertFormState();
}

class _ConvertFormState extends State<ConvertForm> {
  final _form = GlobalKey<FormState>();
  final _congregationFocus = FocusNode(debugLabel: 'convert-congregation');
  final _nameFocus = FocusNode(debugLabel: 'convert-name');
  final _phoneFocus = FocusNode(debugLabel: 'convert-phone');
  final _birthDateFocus = FocusNode(debugLabel: 'convert-birth-date');
  final _landmarkFocus = FocusNode(debugLabel: 'convert-landmark');
  final _ageFocus = FocusNode(debugLabel: 'convert-age');
  final _genderFocus = FocusNode(debugLabel: 'convert-gender');
  final _dateFocus = FocusNode(debugLabel: 'convert-date');
  final _worshipFocus = FocusNode(debugLabel: 'convert-worship');
  late final TextEditingController _name,
      _address,
      _district,
      _city,
      _postalCode,
      _stateCode,
      _landmark,
      _phone,
      _birthDate,
      _age,
      _date;
  String? _congregation, _worship;
  Gender? _gender;
  Uint8List? _photo;
  NormalizedPhotoCrop? _photoCrop;
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
    _district = TextEditingController(
      text: identityAddress?['district'] as String?,
    );
    _city = TextEditingController(text: identityAddress?['city'] as String?);
    _postalCode = TextEditingController(
      text: identityAddress?['postal_code'] as String?,
    );
    _stateCode = TextEditingController(
      text: identityAddress?['state_code'] as String?,
    );
    _landmark = TextEditingController(text: i?.landmark);
    _phone = TextEditingController(
      text: brPhoneDisplay(
        identity?.phone ?? i?.legacyIdentity?.phone ?? i?.phone,
      ),
    );
    _birthDate = TextEditingController(
      text: brDateDisplay(identity?.birthDate?.toString()),
    );
    _age = TextEditingController(text: i?.age?.toString());
    _date = TextEditingController(
      text: brDateDisplay(i?.conversionDate.toString()),
    );
    _congregation = i?.congregationId;
    _worship = i?.worshipType;
    _gender = i?.gender;
  }

  bool _photoAllowedFor(String? congregationId) =>
      widget.allowPhotos &&
      congregationId != null &&
      (widget.photoAuthority?.call(congregationId) ?? true);

  void _clearSelectedPhoto() {
    _photo?.fillRange(0, _photo!.length, 0);
    _photo = null;
    _photoCrop = null;
  }

  void _selectCongregation(String? congregationId) {
    final wasAllowed = _photoAllowedFor(_congregation);
    final willBeAllowed = _photoAllowedFor(congregationId);
    setState(() {
      _congregation = congregationId;
      if (!willBeAllowed) {
        _clearSelectedPhoto();
        _removePhoto = false;
      }
    });
    if (wasAllowed && !willBeAllowed) {
      widget.onPhotoAuthorityRevoked?.call();
    }
    widget.onCongregationChanged?.call(congregationId);
  }

  @override
  void didUpdateWidget(covariant ConvertForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasAllowed =
        oldWidget.allowPhotos &&
        _congregation != null &&
        (oldWidget.photoAuthority?.call(_congregation) ?? true);
    if (wasAllowed && !_photoAllowedFor(_congregation)) {
      _clearSelectedPhoto();
      _removePhoto = false;
      widget.onPhotoAuthorityRevoked?.call();
    }
  }

  @override
  void dispose() {
    for (final focus in [
      _congregationFocus,
      _nameFocus,
      _phoneFocus,
      _birthDateFocus,
      _landmarkFocus,
      _ageFocus,
      _genderFocus,
      _dateFocus,
      _worshipFocus,
    ]) {
      focus.dispose();
    }
    for (final c in [
      _name,
      _address,
      _district,
      _city,
      _postalCode,
      _stateCode,
      _landmark,
      _phone,
      _birthDate,
      _age,
      _date,
    ]) {
      c.clear();
      c.dispose();
    }
    _clearSelectedPhoto();
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

  Future<bool> _revalidatePhotoScope(
    String? congregationId,
    String? token,
  ) async {
    if (!_current(token) ||
        congregationId != _congregation ||
        !_photoAllowedFor(_congregation)) {
      return false;
    }
    final authorized = await widget.revalidatePhotoAuthority?.call(
      congregationId,
    );
    if (!_current(token)) return false;
    if (authorized == false) {
      if (mounted) {
        setState(() {
          _clearSelectedPhoto();
          _removePhoto = false;
          _error = 'Seu acesso mudou. Atualize a página antes de enviar fotos.';
        });
        widget.onPhotoAuthorityRevoked?.call();
      }
      return false;
    }
    return congregationId == _congregation && _photoAllowedFor(_congregation);
  }

  Future<void> _pick() async {
    final congregationId = _congregation;
    if (_picking ||
        _busy ||
        widget.submissionLocked ||
        !_photoAllowedFor(congregationId)) {
      return;
    }
    final token = widget.gateway?.context;
    setState(() {
      _picking = true;
      _error = null;
    });
    Uint8List? source;
    try {
      if (!await _revalidatePhotoScope(congregationId, token)) return;
      NormalizedPhotoCrop? crop;
      if (widget.pickPhoto != null) {
        source = await widget.pickPhoto!();
      } else {
        if (!mounted) return;
        final imageSource = await widget.choosePhotoSource(context);
        if (!_current(token) ||
            congregationId != _congregation ||
            !_photoAllowedFor(_congregation) ||
            imageSource == null) {
          return;
        }
        if (!await _revalidatePhotoScope(congregationId, token)) return;
        source = await widget.acquirePhoto(imageSource);
        if (source == null) return;
        if (!await _revalidatePhotoScope(congregationId, token)) return;
        if (!mounted) return;
        crop = await widget.cropPhoto(context, source);
        if (!_current(token) ||
            congregationId != _congregation ||
            !_photoAllowedFor(_congregation) ||
            crop == null) {
          return;
        }
        if (!await _revalidatePhotoScope(congregationId, token)) return;
      }
      if (source == null) return;
      if (!_current(token) ||
          congregationId != _congregation ||
          !_photoAllowedFor(_congregation)) {
        return;
      }
      if (source.isEmpty || source.length > 20 * 1024 * 1024) {
        throw const DataFailure('invalid');
      }
      final selected = Uint8List.fromList(source);
      setState(() {
        _clearSelectedPhoto();
        _photo = selected;
        _photoCrop = crop;
        _removePhoto = false;
      });
    } catch (_) {
      if (_current(token)) {
        setState(
          () => _error = 'Não foi possível abrir a foto. Escolha outra imagem.',
        );
      }
    } finally {
      if (_current(token)) setState(() => _picking = false);
      source?.fillRange(0, source.length, 0);
    }
  }

  DateOnly? _parsedDate() {
    final date = parseDateInput(_date.text);
    return date == null ? null : DateOnly(date.year, date.month, date.day);
  }

  DateOnly? _parsedBirthDate() {
    final date = parseDateInput(_birthDate.text);
    return date == null ? null : DateOnly(date.year, date.month, date.day);
  }

  bool _validateAndFocusFirstInvalid() {
    if (_form.currentState!.validate()) return true;
    final inheritedName = widget.initial?.personIdentity?.name;
    final name = _name.text.trim();
    if (widget.requireCongregation && _congregation == null) {
      _congregationFocus.requestFocus();
    } else if (name.isEmpty ||
        (_name.text != inheritedName && name.length > 200)) {
      _nameFocus.requestFocus();
    } else if (brPhoneValidationError(_phone.text) != null) {
      _phoneFocus.requestFocus();
    } else if (brDateValidationError(_birthDate.text) != null) {
      _birthDateFocus.requestFocus();
    } else if (_landmark.text.trim().isEmpty) {
      _landmarkFocus.requestFocus();
    } else if (_age.text.isNotEmpty &&
        (int.tryParse(_age.text) == null ||
            int.parse(_age.text) < 0 ||
            int.parse(_age.text) > 150)) {
      _ageFocus.requestFocus();
    } else if (_gender == null) {
      _genderFocus.requestFocus();
    } else {
      final dateError = brDateValidationError(_date.text, required: true);
      final date = _parsedDate();
      if (dateError != null ||
          date == null ||
          date.compareTo(BusinessCalendar().today(widget.now())) > 0) {
        _dateFocus.requestFocus();
      } else if (_worship == null || _worship!.trim().isEmpty) {
        _worshipFocus.requestFocus();
      }
    }
    return false;
  }

  Future<void> _submit() async {
    if (_busy ||
        _picking ||
        widget.submissionLocked ||
        !_validateAndFocusFirstInvalid()) {
      return;
    }
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
        oldPerson != null &&
        oldAddress == null &&
        [
          _address,
          _district,
          _city,
          _postalCode,
          _stateCode,
        ].every((controller) => controller.text.trim().isEmpty);
    final name = _name.text == oldName ? oldName! : _name.text.trim();
    final draft = ConvertDraft(
      name: name,
      landmark: _landmark.text.trim(),
      gender: _gender!,
      conversionDate: _parsedDate()!,
      worshipType: _worship!,
      address: optional(_address, oldAddressStreet),
      phone: resolveBrPhone(_phone.text),
      birthDate: _parsedBirthDate(),
      personAddress: {
        'street': optional(_address, oldAddressStreet),
        'district': optional(_district, oldAddress?['district'] as String?),
        'city': optional(_city, oldAddress?['city'] as String?),
        'postal_code': optional(
          _postalCode,
          oldAddress?['postal_code'] as String?,
        ),
        'state_code': optional(
          _stateCode,
          oldAddress?['state_code'] as String?,
        ),
      },
      preserveNullAddress: preserveNullAddress,
      congregationId: _congregation,
      age: _age.text.isEmpty ? null : int.parse(_age.text),
      photoBytes: !_photoAllowedFor(_congregation) || _photo == null
          ? null
          : Uint8List.fromList(_photo!),
      photoCrop: !_photoAllowedFor(_congregation) || _photo == null
          ? null
          : _photoCrop,
      removePhoto: _photoAllowedFor(_congregation) && _removePhoto,
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
    FocusNode? focusNode,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AppTextFormField(
      fieldKey: ValueKey(key),
      controller: c,
      readOnly: _busy || widget.submissionLocked,
      keyboardType: keyboard,
      validator: validator,
      focusNode: focusNode,
      onChanged: (_) => setState(() {}),
      label: label,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final photoAllowed = _photoAllowedFor(_congregation);
    final old = photoAllowed ? widget.existingPhoto : null;
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
                if (photoAllowed) ...[
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
                        onPressed: _busy || _picking || widget.submissionLocked
                            ? null
                            : _pick,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          _picking ? 'Abrindo foto…' : 'Escolher foto',
                        ),
                      ),
                      if (_photo != null ||
                          old != null ||
                          widget.initial?.photoAssetId != null)
                        TextButton(
                          onPressed: _busy || widget.submissionLocked
                              ? null
                              : () => setState(() {
                                  _clearSelectedPhoto();
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
                  if (_removePhoto)
                    const Text('A foto será removida ao salvar.'),
                ],
                DropdownButtonFormField<String>(
                  key: const ValueKey('convert-congregation'),
                  focusNode: _congregationFocus,
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
                  onChanged:
                      !widget.allowCongregationChange ||
                          _busy ||
                          _picking ||
                          widget.submissionLocked
                      ? null
                      : _selectCongregation,
                  validator: (v) => widget.requireCongregation && v == null
                      ? 'Selecione uma congregação'
                      : null,
                ),
                const SizedBox(height: 16),
                PersonFields(
                  name: _name,
                  phone: _phone,
                  birthDate: _birthDate,
                  street: _address,
                  district: _district,
                  city: _city,
                  postalCode: _postalCode,
                  stateCode: _stateCode,
                  enabled: !_busy && !widget.submissionLocked,
                  nameFocusNode: _nameFocus,
                  phoneFocusNode: _phoneFocus,
                  birthDateFocusNode: _birthDateFocus,
                  nameValidator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Nome é obrigatório';
                    final inherited = widget.initial?.personIdentity?.name;
                    if (value != inherited && name.length > 200) {
                      return 'Reduza o nome para até 200 caracteres';
                    }
                    return null;
                  },
                  birthDateValidator: brDateValidationError,
                ),
                _field(
                  'landmark',
                  'Ponto de referência *',
                  _landmark,
                  validator: (v) => v!.trim().isEmpty
                      ? 'Ponto de referência é obrigatório'
                      : null,
                  focusNode: _landmarkFocus,
                ),
                _field(
                  'age',
                  'Idade',
                  _age,
                  keyboard: TextInputType.number,
                  focusNode: _ageFocus,
                  validator: (v) => v!.isEmpty
                      ? null
                      : (int.tryParse(v) == null ||
                                int.parse(v) < 0 ||
                                int.parse(v) > 150
                            ? 'Informe uma idade entre 0 e 150'
                            : null),
                ),
                DropdownButtonFormField<Gender>(
                  key: const ValueKey('convert-gender'),
                  focusNode: _genderFocus,
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
                  onChanged: _busy || widget.submissionLocked
                      ? null
                      : (v) => setState(() => _gender = v),
                  validator: (v) => v == null ? 'Gênero é obrigatório' : null,
                ),
                const SizedBox(height: 16),
                BrDateField(
                  fieldKey: const ValueKey('conversion_date'),
                  controller: _date,
                  label: 'Data de conversão *',
                  enabled: !_busy && !widget.submissionLocked,
                  focusNode: _dateFocus,
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
                  key: const ValueKey('convert-worship'),
                  focusNode: _worshipFocus,
                  initialValue: _worship,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de culto *',
                  ),
                  items: [
                    for (final w in worships)
                      DropdownMenuItem(value: w, child: Text(w)),
                  ],
                  onChanged: _busy || widget.submissionLocked
                      ? null
                      : (v) => setState(() => _worship = v),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Tipo de culto é obrigatório'
                      : null,
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
                      onPressed: _busy || widget.submissionLocked
                          ? null
                          : widget.onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          _busy ||
                              _picking ||
                              widget.submissionLocked ||
                              !widget.submitEnabled
                          ? null
                          : _submit,
                      icon: Icon(
                        _busy ? Icons.hourglass_top : Icons.save_outlined,
                      ),
                      label: Text(
                        _busy
                            ? 'Salvando…'
                            : widget.submitLabel ??
                                  (widget.initial == null
                                      ? 'Cadastrar'
                                      : 'Atualizar'),
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
