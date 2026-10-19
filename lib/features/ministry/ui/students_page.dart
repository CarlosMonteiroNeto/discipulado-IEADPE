import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../data/ministry_codec.dart';

import 'package:flutter/material.dart';

import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_browser_repository.dart';
import '../domain/ministry_models.dart';
import '../../../domain/business_calendar.dart';
import '../../../domain/models.dart' as app_models;
import '../data/ministry_repository.dart';
import '../../people/person_fields.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.onOpenHandoff,
    this.onRegister,
  });
  final MinistryBrowserRepository repository;
  final String congregationId;
  final VoidCallback onOpenHandoff;
  final VoidCallback? onRegister;
  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final _search = TextEditingController();
  MinistryPage<MinistryStudentSummary>? _page;
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? cursor}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.listStudents(
        congregationId: widget.congregationId,
        namePrefix: _search.text.trim().isEmpty ? null : _search.text.trim(),
        cursor: cursor,
      );
      if (mounted) {
        setState(() {
          _page = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar os alunos. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Base44PageHeading(
                title: 'Alunos',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 16),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Os dados pessoais vêm da identidade canônica; as informações escolares permanecem no cadastro do aluno.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: widget.onOpenHandoff,
                      icon: const Icon(Icons.move_to_inbox_outlined),
                      label: const Text('Revisar novos convertidos'),
                    ),
                    if (widget.onRegister != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: widget.onRegister,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Registrar aluno'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Buscar aluno pelo nome',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _loading ? null : () => _load(),
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        TextButton.icon(
                          onPressed: _loading ? null : () => _load(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Base44Panel(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando alunos',
                    ),
                  ),
                ),
              if (_error != null)
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!, semanticsLabel: 'Falha ao carregar alunos'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _load(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              if (!_loading && _error == null && _page?.items.isEmpty == true)
                const Base44Panel(child: Text('Nenhum aluno encontrado.')),
              for (final student
                  in _page?.items ?? const <MinistryStudentSummary>[])
                Card(
                  child: ListTile(
                    title: Text(student.name, softWrap: true),
                    subtitle: Text(
                      student.linkState == PersonLinkState.linked
                          ? 'Identidade canônica vinculada'
                          : 'Identidade pendente de revisão',
                      softWrap: true,
                    ),
                    leading: Icon(
                      student.linkState == PersonLinkState.linked
                          ? Icons.link
                          : Icons.school_outlined,
                      color: UnifiedColors.brandNavy,
                    ),
                    trailing: student.phone == null
                        ? null
                        : const Tooltip(
                            message: 'Telefone cadastrado',
                            child: Icon(Icons.phone_outlined),
                          ),
                    minVerticalPadding: 12,
                  ),
                ),
              if (_page?.nextCursor != null)
                Base44Panel(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _load(cursor: _page!.nextCursor),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Próxima página'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One atomic canonical-person plus student registration form.
class StudentRegistrationPage extends StatefulWidget {
  const StudentRegistrationPage({
    super.key,
    required this.repository,
    required this.congregationId,
    this.onCancel,
    required this.onSaved,
  });

  final MinistryRepository repository;
  final String congregationId;
  final VoidCallback? onCancel;
  final ValueChanged<app_models.PersonRegistrationResult> onSaved;

  @override
  State<StudentRegistrationPage> createState() =>
      _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _phone,
      _birthDate,
      _street,
      _district,
      _city,
      _postalCode,
      _stateCode,
      _education,
      _maritalStatus;
  bool? _waterBaptized, _wantsBaptism;
  bool _busy = false;
  String? _error;
  String? _signature, _operationId, _studentId, _personId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _birthDate = TextEditingController();
    _street = TextEditingController();
    _district = TextEditingController();
    _city = TextEditingController();
    _postalCode = TextEditingController();
    _stateCode = TextEditingController();
    _education = TextEditingController();
    _maritalStatus = TextEditingController();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _birthDate,
      _street,
      _district,
      _city,
      _postalCode,
      _stateCode,
      _education,
      _maritalStatus,
    ]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  DateOnly? _date() {
    if (_birthDate.text.trim().isEmpty) return null;
    try {
      return DateOnly.parse(_birthDate.text.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_waterBaptized == true && _wantsBaptism == true) {
      setState(() => _error = 'Confira as respostas sobre batismo.');
      return;
    }
    final date = _date();
    final street = _optional(_street);
    final district = _optional(_district);
    final city = _optional(_city);
    final postalCode = _optional(_postalCode);
    final stateCode = _optional(_stateCode);
    final address =
        street == null &&
            district == null &&
            city == null &&
            postalCode == null &&
            stateCode == null
        ? null
        : Address(
            street: street,
            district: district,
            city: city,
            postalCode: postalCode,
            stateCode: stateCode,
          );
    final person = MinistryPersonDraft(
      name: _name.text.trim(),
      phone: _optional(_phone),
      birthDate: date == null
          ? null
          : CalendarDate(date.year, date.month, date.day),
      address: address,
    );
    final fields = <String, Object?>{
      'person': person.toJson(),
      'education': _optional(_education),
      'marital_status': _optional(_maritalStatus),
      'new_convert': false,
      'water_baptized': _waterBaptized,
      'wants_baptism': _wantsBaptism,
      'congregation_id': widget.congregationId,
    };
    final signature = jsonEncode(fields);
    if (_signature != signature) {
      _signature = signature;
      _operationId = const Uuid().v4();
      _studentId = const Uuid().v4();
      _personId = const Uuid().v4();
    }
    final token = widget.repository.gateway.context;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.registerStudent(
        operationId: _operationId!,
        studentId: _studentId!,
        personId: _personId!,
        congregationId: widget.congregationId,
        person: person,
        education: fields['education'] as String?,
        maritalStatus: fields['marital_status'] as String?,
        newConvert: false,
        waterBaptized: _waterBaptized,
        wantsBaptism: _wantsBaptism,
      );
      widget.repository.gateway.ensureCurrent(token);
      if (mounted) widget.onSaved(result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is DataFailure && error.code == 'permission'
              ? 'Seu acesso mudou. Volte e atualize a página.'
              : 'Não foi possível cadastrar o aluno. Seus dados foram mantidos. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _academicTextField(
    String key,
    String label,
    TextEditingController controller,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _answerField(
    String key,
    String label,
    bool? value,
    ValueChanged<bool?> onChanged,
  ) => DropdownButtonFormField<bool?>(
    key: ValueKey(key),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: const [
      DropdownMenuItem(value: null, child: Text('Não informado')),
      DropdownMenuItem(value: false, child: Text('Não')),
      DropdownMenuItem(value: true, child: Text('Sim')),
    ],
    onChanged: _busy ? null : onChanged,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Registrar aluno'),
                      const SizedBox(height: 8),
                      const Text(
                        'Este cadastro cria a identidade e os dados acadêmicos do aluno. Ele não registra uma conversão.',
                      ),
                      const SizedBox(height: 16),
                      PersonFields(
                        name: _name,
                        phone: _phone,
                        birthDate: _birthDate,
                        street: _street,
                        district: _district,
                        city: _city,
                        postalCode: _postalCode,
                        stateCode: _stateCode,
                        enabled: !_busy,
                        nameValidator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.isEmpty) return 'Nome é obrigatório';
                          if (name.length > 200) {
                            return 'O nome deve ter até 200 caracteres';
                          }
                          return null;
                        },
                        birthDateValidator: (value) =>
                            value == null ||
                                value.trim().isEmpty ||
                                _date() != null
                            ? null
                            : 'Informe uma data válida (aaaa-mm-dd)',
                      ),
                      _academicTextField(
                        'student-education',
                        'Escolaridade (opcional)',
                        _education,
                      ),
                      _academicTextField(
                        'student-marital-status',
                        'Estado civil (opcional)',
                        _maritalStatus,
                      ),
                      _answerField(
                        'student-water-baptized',
                        'Batizado nas águas?',
                        _waterBaptized,
                        (value) => setState(() => _waterBaptized = value),
                      ),
                      const SizedBox(height: 12),
                      _answerField(
                        'student-wants-baptism',
                        'Deseja ser batizado?',
                        _wantsBaptism,
                        (value) => setState(() => _wantsBaptism = value),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(_error!),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: _busy ? null : widget.onCancel,
                            child: const Text('Cancelar'),
                          ),
                          FilledButton.icon(
                            onPressed: _busy ? null : _submit,
                            icon: Icon(
                              _busy ? Icons.hourglass_top : Icons.save_outlined,
                            ),
                            label: Text(
                              _busy ? 'Salvando…' : 'Cadastrar aluno',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
