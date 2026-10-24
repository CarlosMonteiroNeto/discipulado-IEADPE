import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/br_input.dart';
import '../../../ui/form_fields.dart';
import '../../people/person_fields.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import 'enrollment_progress_panel.dart';

class StudentDetailPage extends StatefulWidget {
  const StudentDetailPage({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.studentId,
  });

  final MinistryRepository repository;
  final String congregationId;
  final String studentId;

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  final _uuid = const Uuid();
  final _personForm = GlobalKey<FormState>();
  final _academicForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _birthDate = TextEditingController();
  final _street = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _stateCode = TextEditingController();
  final _education = TextEditingController();
  final _maritalStatus = TextEditingController();
  MinistryStudentDetail? _student;
  MinistryPerson? _person;
  bool? _newConvert;
  bool? _waterBaptized;
  bool? _wantsBaptism;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  String? _personSignature;
  String? _personOperationId;
  String? _academicSignature;
  String? _academicOperationId;
  final Map<String, String> _archiveOperationIds = {};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StudentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId ||
        oldWidget.studentId != widget.studentId) {
      _clearFields();
      _student = null;
      _person = null;
      _load();
    }
  }

  @override
  void dispose() {
    _clearFields();
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
      controller.dispose();
    }
    super.dispose();
  }

  void _clearFields() {
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
    }
    _newConvert = null;
    _waterBaptized = null;
    _wantsBaptism = null;
    _personSignature = null;
    _personOperationId = null;
    _academicSignature = null;
    _academicOperationId = null;
  }

  void _hydrate(MinistryStudentDetail student, MinistryPerson? person) {
    _name.text = person?.name ?? student.name;
    _phone.text = brPhoneDisplay(person?.phone ?? student.phoneE164);
    _birthDate.text = brDateDisplay(
      person?.birthDate?.toString() ?? student.birthDate?.toString(),
    );
    final address = person?.address ?? student.address;
    _street.text = address?.street ?? '';
    _district.text = address?.district ?? '';
    _city.text = address?.city ?? '';
    _postalCode.text = address?.postalCode ?? '';
    _stateCode.text = address?.stateCode ?? '';
    _education.text = student.education ?? '';
    _maritalStatus.text = student.maritalStatus ?? '';
    _newConvert = student.newConvert;
    _waterBaptized = student.waterBaptized;
    _wantsBaptism = student.wantsBaptism;
    _personSignature = null;
    _personOperationId = null;
    _academicSignature = null;
    _academicOperationId = null;
  }

  Future<void> _load({bool clearNotice = true}) async {
    final generation = ++_loadGeneration;
    final scopeId = widget.congregationId;
    final studentId = widget.studentId;
    setState(() {
      _loading = true;
      _error = null;
      if (clearNotice) _notice = null;
    });
    try {
      final student = await widget.repository.getStudent(
        congregationId: scopeId,
        studentId: studentId,
      );
      final person = student.personId == null
          ? null
          : await widget.repository.getPerson(
              congregationId: scopeId,
              personId: student.personId!,
            );
      if (!mounted ||
          generation != _loadGeneration ||
          scopeId != widget.congregationId ||
          studentId != widget.studentId) {
        return;
      }
      setState(() {
        _student = student;
        _person = person;
        _hydrate(student, person);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _student = null;
        _person = null;
        _error = error is DataFailure && error.code == 'permission'
            ? 'Seu acesso mudou. Volte e atualize a sessão.'
            : 'Não foi possível carregar os dados do aluno.';
      });
    }
  }

  String? _optional(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  CalendarDate? _date() {
    final date = parseDateInput(_birthDate.text);
    return date == null ? null : CalendarDate(date.year, date.month, date.day);
  }

  Address? _address() {
    final street = _optional(_street);
    final district = _optional(_district);
    final city = _optional(_city);
    final postalCode = _optional(_postalCode);
    final stateCode = _optional(_stateCode);
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

  Future<void> _savePerson() async {
    final student = _student;
    final person = _person;
    if (_busy || student == null || person == null || !_canEdit) return;
    if (!_personForm.currentState!.validate()) return;
    final draft = MinistryPersonDraft(
      name: _name.text.trim(),
      phone: resolveBrPhone(_phone.text),
      birthDate: _date(),
      address: _address(),
    );
    final signature = jsonEncode({
      'congregation_id': student.congregationId,
      'student_id': student.id,
      'person_revision': person.revision,
      ...draft.toJson(),
    });
    if (_personSignature != signature) {
      _personSignature = signature;
      _personOperationId = _uuid.v4();
    }
    final token = widget.repository.gateway.context;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.repository.savePerson(
        operationId: _personOperationId!,
        id: person.id,
        congregationId: student.congregationId,
        expectedRevision: person.revision,
        person: draft,
      );
      widget.repository.gateway.ensureCurrent(token);
      if (mounted) {
        setState(() => _notice = 'Identidade atualizada.');
        await _load(clearNotice: false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _saveError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAcademic() async {
    final student = _student;
    if (_busy || student == null || !_canEdit) return;
    if (!_academicForm.currentState!.validate()) return;
    if (_waterBaptized == true && _wantsBaptism == true) {
      setState(() => _error = 'Confira as respostas sobre batismo.');
      return;
    }
    final signature = jsonEncode({
      'congregation_id': student.congregationId,
      'student_id': student.id,
      'revision': student.revision,
      'education': _optional(_education),
      'marital_status': _optional(_maritalStatus),
      'new_convert': _newConvert,
      'water_baptized': _waterBaptized,
      'wants_baptism': _wantsBaptism,
    });
    if (_academicSignature != signature) {
      _academicSignature = signature;
      _academicOperationId = _uuid.v4();
    }
    final token = widget.repository.gateway.context;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.repository.saveStudent(
        operationId: _academicOperationId!,
        id: student.id,
        congregationId: student.congregationId,
        expectedRevision: student.revision,
        education: _optional(_education),
        maritalStatus: _optional(_maritalStatus),
        newConvert: _newConvert,
        waterBaptized: _waterBaptized,
        wantsBaptism: _wantsBaptism,
      );
      widget.repository.gateway.ensureCurrent(token);
      if (mounted) {
        setState(() => _notice = 'Dados acadêmicos atualizados.');
        await _load(clearNotice: false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _saveError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setArchived() async {
    final student = _student;
    if (_busy || student == null) return;
    final archived = student.archivedAt == null;
    final signature = '${student.id}:${student.revision}:$archived';
    final operationId = _archiveOperationIds.putIfAbsent(signature, _uuid.v4);
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.repository.setStudentArchived(
        operationId: operationId,
        id: student.id,
        congregationId: student.congregationId,
        archived: archived,
        expectedRevision: student.revision,
      );
      if (mounted) {
        setState(
          () => _notice = archived ? 'Aluno arquivado.' : 'Aluno restaurado.',
        );
        await _load(clearNotice: false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _archiveError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canEdit => _student?.archivedAt == null;

  String _saveError(Object error) => switch (error) {
    DataFailure(code: 'permission') =>
      'Seu acesso mudou. Atualize a sessão para continuar.',
    DataFailure(code: 'stale_revision') =>
      'Outro usuário atualizou estes dados. Recarregue antes de salvar.',
    DataFailure(code: 'invalid') => 'Confira os campos e tente novamente.',
    DataFailure(code: 'unavailable') => 'Serviço indisponível. Os dados e o código da operação foram mantidos; tente novamente.',
    _ => 'Não foi possível salvar. Os dados foram mantidos para uma nova tentativa.',
  };

  String _archiveError(Object error) => switch (error) {
    DataFailure(code: 'permission') =>
      'Seu acesso mudou. Atualize a sessão para continuar.',
    DataFailure(code: 'active_enrollment') =>
      'Este aluno tem uma matrícula ativa e não pode ser arquivado.',
    DataFailure(code: 'stale_revision') => 'Outro usuário atualizou este cadastro. Recarregue antes de tentar novamente.',
    _ => 'Não foi possível alterar o estado do aluno. Tente novamente.',
  };

  Widget _answerField(
    String key,
    String label,
    bool? value,
    ValueChanged<bool?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<bool?>(
      key: ValueKey(key),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: null, child: Text('Não informado')),
        DropdownMenuItem(value: false, child: Text('Não')),
        DropdownMenuItem(value: true, child: Text('Sim')),
      ],
      onChanged: !_canEdit || _busy ? null : onChanged,
    ),
  );

  Widget _personSection(MinistryStudentDetail student) {
    final enabled = _canEdit && _person != null && !_busy;
    return Base44Panel(
      child: Form(
        key: _personForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Identidade canônica',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_person == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Este aluno ainda não tem identidade canônica vinculada. O nome e os contatos abaixo são apenas o registro legado; não há vínculo automático por nome.',
                ),
              ),
            PersonFields(
              name: _name,
              phone: _phone,
              birthDate: _birthDate,
              street: _street,
              district: _district,
              city: _city,
              postalCode: _postalCode,
              stateCode: _stateCode,
              enabled: enabled,
              nameValidator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Nome é obrigatório';
                if (name.length > 200) {
                  return 'O nome deve ter até 200 caracteres';
                }
                return null;
              },
              birthDateValidator: brDateValidationError,
            ),
            if (_person != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: enabled ? _savePerson : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar identidade'),
                ),
              ),
            if (student.archivedAt != null)
              Text(
                'Arquivado em ${student.archivedAt!.toLocal().toString().substring(0, 16)}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _academicSection(MinistryStudentDetail student) => Base44Panel(
    child: Form(
      key: _academicForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dados acadêmicos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          AppTextFormField(
            fieldKey: const ValueKey('student-detail-education'),
            controller: _education,
            enabled: _canEdit && !_busy,
            label: 'Escolaridade',
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            fieldKey: const ValueKey('student-detail-marital-status'),
            controller: _maritalStatus,
            enabled: _canEdit && !_busy,
            label: 'Estado civil',
          ),
          const SizedBox(height: 16),
          _answerField(
            'student-detail-new-convert',
            'Convertido recentemente?',
            _newConvert,
            (value) => setState(() => _newConvert = value),
          ),
          _answerField(
            'student-detail-water-baptized',
            'Batizado nas águas?',
            _waterBaptized,
            (value) => setState(() => _waterBaptized = value),
          ),
          _answerField(
            'student-detail-wants-baptism',
            'Deseja ser batizado?',
            _wantsBaptism,
            (value) => setState(() => _wantsBaptism = value),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _canEdit && !_busy ? _saveAcademic : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar dados acadêmicos'),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: Text(_student?.name ?? 'Dados do aluno'),
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading)
                const Base44Panel(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando dados do aluno',
                    ),
                  ),
                ),
              if (_error != null)
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(liveRegion: true, child: Text(_error!)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _loading ? null : _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Recarregar dados'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_notice != null)
                Base44Panel(
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
              if (_student case final student?) ...[
                _personSection(student),
                const SizedBox(height: 12),
                _academicSection(student),
                const SizedBox(height: 12),
                _EnrollmentHistorySection(
                  key: ValueKey('${widget.congregationId}:${widget.studentId}'),
                  repository: widget.repository,
                  congregationId: widget.congregationId,
                  studentId: widget.studentId,
                ),
                const SizedBox(height: 12),
                Base44Panel(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recarregar'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _setArchived,
                        icon: Icon(
                          student.archivedAt == null
                              ? Icons.archive_outlined
                              : Icons.unarchive_outlined,
                        ),
                        label: Text(
                          student.archivedAt == null
                              ? 'Arquivar aluno'
                              : 'Restaurar aluno',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Salvando dados do aluno',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Bounded, paginated enrollment history for one student.
///
/// Progress is fetched only for the explicitly selected enrollment. A new
/// selection replaces the previous panel state, so an obsolete reply can never
/// render under another student, scope or enrollment.
class _EnrollmentHistorySection extends StatefulWidget {
  const _EnrollmentHistorySection({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.studentId,
  });

  final MinistryRepository repository;
  final String congregationId;
  final String studentId;

  @override
  State<_EnrollmentHistorySection> createState() =>
      _EnrollmentHistorySectionState();
}

/// Ownership of the most recent failed enrollment-history request.
enum _EnrollmentHistoryOperation { firstPage, more }

class _EnrollmentHistorySectionState extends State<_EnrollmentHistorySection> {
  List<StudentEnrollmentSummary> _items = const [];
  String? _nextCursor;
  String? _selectedEnrollmentId;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  _EnrollmentHistoryOperation? _failedOperation;
  int _generation = 0;
  int _progressGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  @override
  void didUpdateWidget(covariant _EnrollmentHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId ||
        oldWidget.studentId != widget.studentId) {
      _items = const [];
      _nextCursor = null;
      _selectedEnrollmentId = null;
      _error = null;
      _failedOperation = null;
      _loadFirst();
    }
  }

  Future<void> _loadFirst({bool refresh = false}) async {
    final generation = ++_generation;
    final congregationId = widget.congregationId;
    final studentId = widget.studentId;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _failedOperation = null;
      if (refresh) _progressGeneration++;
    });
    try {
      final page = await widget.repository.listStudentEnrollments(
        congregationId: congregationId,
        studentId: studentId,
        limit: 50,
      );
      if (!mounted ||
          generation != _generation ||
          congregationId != widget.congregationId ||
          studentId != widget.studentId) {
        return;
      }
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
        _failedOperation = null;
        if (!_items.any((item) => item.id == _selectedEnrollmentId)) {
          _selectedEnrollmentId = null;
        }
      });
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          congregationId != widget.congregationId ||
          studentId != widget.studentId) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _message(error);
        _failedOperation = _EnrollmentHistoryOperation.firstPage;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    final generation = _generation;
    final congregationId = widget.congregationId;
    final studentId = widget.studentId;
    setState(() {
      _loadingMore = true;
      _error = null;
      _failedOperation = null;
    });
    try {
      final page = await widget.repository.listStudentEnrollments(
        congregationId: congregationId,
        studentId: studentId,
        limit: 50,
        cursor: cursor,
      );
      if (!mounted ||
          generation != _generation ||
          congregationId != widget.congregationId ||
          studentId != widget.studentId) {
        return;
      }
      setState(() {
        _items = List.unmodifiable([..._items, ...page.items]);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
        _failedOperation = null;
      });
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          congregationId != widget.congregationId ||
          studentId != widget.studentId) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _error = _message(error);
        _failedOperation = _EnrollmentHistoryOperation.more;
      });
    }
  }

  void _retry() {
    switch (_failedOperation) {
      case _EnrollmentHistoryOperation.firstPage:
        _loadFirst();
      case _EnrollmentHistoryOperation.more:
        _loadMore();
      case null:
        if (_items.isEmpty || _nextCursor == null) {
          _loadFirst();
        } else {
          _loadMore();
        }
    }
  }

  void _toggle(String enrollmentId) {
    setState(() {
      _selectedEnrollmentId = _selectedEnrollmentId == enrollmentId
          ? null
          : enrollmentId;
    });
  }

  String _message(Object error) {
    if (error is DataFailure) {
      return switch (error.code) {
        'permission' || 'forbidden' =>
          'Seu acesso mudou. Volte e atualize a sessão para ver o histórico.',
        'stale' =>
          'Sua sessão ou congregação mudou. Atualize a página para continuar.',
        _ => 'Não foi possível carregar o histórico de matrículas.',
      };
    }
    return 'Não foi possível carregar o histórico de matrículas.';
  }

  String _statusLabel(EnrollmentStatus status) => switch (status) {
    EnrollmentStatus.active => 'Ativa',
    EnrollmentStatus.completed => 'Concluída',
    EnrollmentStatus.withdrawn => 'Desistência',
  };

  Widget _enrollmentRow(StudentEnrollmentSummary item) {
    final selected = _selectedEnrollmentId == item.id;
    final end = item.endDate?.toString() ?? 'em andamento';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.className, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(_statusLabel(item.status)),
              Text('Início: ${item.startDate}'),
              Text('Término: $end'),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label:
                  '${selected ? 'Ocultar' : 'Ver'} progresso da matrícula em '
                  '${item.className}',
              onTap: () => _toggle(item.id),
              child: ExcludeSemantics(
                child: TextButton(
                  key: Key('enrollment-progress-${item.id}'),
                  onPressed: () => _toggle(item.id),
                  child: Text(selected ? 'Ocultar progresso' : 'Ver progresso'),
                ),
              ),
            ),
          ),
          if (selected) ...[
            EnrollmentProgressPanel(
              key: ValueKey(
                'student-enrollment-progress-${item.id}-$_progressGeneration',
              ),
              repository: widget.repository,
              congregationId: widget.congregationId,
              enrollmentId: item.id,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Base44Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Histórico de matrículas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              key: const Key('refresh-enrollment-history'),
              onPressed: _loading ? null : () => _loadFirst(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar histórico'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Selecione uma matrícula para consultar o progresso persistido.',
        ),
        const SizedBox(height: 8),
        if (_loading && _items.isEmpty) ...[
          const LinearProgressIndicator(
            semanticsLabel: 'Carregando histórico de matrículas',
          ),
          const SizedBox(height: 8),
          const Text('Carregando histórico de matrículas…'),
        ],
        if (_error != null) ...[
          Semantics(liveRegion: true, child: Text(_error!)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('retry-enrollment-history'),
              onPressed: _loading || _loadingMore ? null : _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ),
        ],
        if (!_loading && _error == null && _items.isEmpty)
          const Text('Nenhuma matrícula registrada para este aluno.'),
        for (final item in _items) ...[const Divider(), _enrollmentRow(item)],
        if (_nextCursor != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('load-more-enrollments'),
              onPressed: _loading || _loadingMore ? null : _loadMore,
              icon: const Icon(Icons.expand_more),
              label: const Text('Carregar mais histórico'),
            ),
          ),
        ],
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              semanticsLabel: 'Carregando mais matrículas',
            ),
          ),
      ],
    ),
  );
}
