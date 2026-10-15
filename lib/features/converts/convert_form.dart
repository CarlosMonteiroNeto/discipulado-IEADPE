import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../domain/worship_types.dart';
import '../../data/supabase_gateway.dart';

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
    this.congregationId,
    this.age,
    this.photoBytes,
    this.removePhoto = false,
  });
  final String name, landmark, worshipType;
  final Gender gender;
  final DateOnly conversionDate;
  final String? address, phone, congregationId;
  final int? age;
  final Uint8List? photoBytes;
  final bool removePhoto;
  Map<String, Object?> payload() => {
    'name': name,
    'landmark': landmark,
    'gender': gender.wireValue,
    'conversion_date': conversionDate.toString(),
    'worship_type': worshipType,
    'address': address,
    'phone': phone,
    'congregation_id': congregationId,
    'age': age,
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
    _name = TextEditingController(text: i?.name);
    _address = TextEditingController(text: i?.address);
    _landmark = TextEditingController(text: i?.landmark);
    _phone = TextEditingController(text: i?.phone);
    _age = TextEditingController(text: i?.age?.toString());
    _date = TextEditingController(text: i?.conversionDate.toString());
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
    try {
      return DateOnly.parse(_date.text);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy || _picking || !_form.currentState!.validate()) return;
    final token = widget.gateway?.context;
    final i = widget.initial;
    String? optional(TextEditingController c, String? old) =>
        c.text == (old ?? '')
        ? old
        : (c.text.trim().isEmpty ? null : c.text.trim());
    final draft = ConvertDraft(
      name: _name.text.trim(),
      landmark: _landmark.text.trim(),
      gender: _gender!,
      conversionDate: _parsedDate()!,
      worshipType: _worship!,
      address: optional(_address, i?.address),
      phone: optional(_phone, i?.phone),
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
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      controller: c,
      readOnly: _busy,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: optional && c.text.isEmpty,
        fillColor: const Color(0xfffff7ed),
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (displayed != null)
                Semantics(
                  label: 'Foto do convertido',
                  child: Image.memory(
                    displayed,
                    height: 96,
                    width: 96,
                    errorBuilder: (_, e, s) =>
                        const Icon(Icons.person, size: 64),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _busy || _picking ? null : _pick,
                    icon: const Icon(Icons.add_a_photo),
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
                  labelText: 'Congregação (opcional)',
                  filled: true,
                  fillColor: Color(0xfffff7ed),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sem congregação'),
                  ),
                  for (final c in congregations.entries)
                    DropdownMenuItem(value: c.key, child: Text(c.value)),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _congregation = v),
              ),
              const SizedBox(height: 16),
              _field(
                'name',
                'Nome *',
                _name,
                validator: (v) =>
                    v!.trim().isEmpty ? 'Nome é obrigatório' : null,
              ),
              _field('address', 'Endereço', _address),
              _field(
                'landmark',
                'Ponto de referência *',
                _landmark,
                validator: (v) => v!.trim().isEmpty
                    ? 'Ponto de referência é obrigatório'
                    : null,
              ),
              _field(
                'phone',
                'Telefone (opcional)',
                _phone,
                optional: true,
                keyboard: TextInputType.phone,
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
              _field(
                'conversion_date',
                'Data de conversão * (aaaa-mm-dd)',
                _date,
                keyboard: TextInputType.datetime,
                validator: (v) {
                  final d = _parsedDate();
                  if (d == null) return 'Informe uma data válida (aaaa-mm-dd)';
                  return d.compareTo(BusinessCalendar().today(widget.now())) > 0
                      ? 'A data não pode ser futura'
                      : null;
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _worship,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de culto *'),
                items: [
                  for (final w in worships)
                    DropdownMenuItem(value: w, child: Text(w)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _worship = v),
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
                  OutlinedButton(
                    onPressed: _busy ? null : widget.onCancel,
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff1e3a5f),
                    ),
                    onPressed: _busy || _picking ? null : _submit,
                    child: Text(
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
    );
  }
}
