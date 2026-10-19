import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../../../domain/models.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_browser_repository.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';

class ClassForm extends StatefulWidget {
  const ClassForm({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.onSaved,
    required this.onCancel,
    this.initialClass,
  });

  final MinistryRepository repository;
  final String congregationId;
  final MinistryClassSummary? initialClass;
  final ValueChanged<MinistryClassSummary> onSaved;
  final VoidCallback onCancel;

  @override
  State<ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<ClassForm> {
  static const _noTeacher = '__no_teacher__';

  final _uuid = const Uuid();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  late String _classId;
  late String _teacherChoice;
  List<MinistryDirectoryEntry> _teachers = const [];
  bool _loadingTeachers = false;
  bool _busy = false;
  bool _mutationAttempted = false;
  String? _teacherError;
  String? _error;
  String? _saveSignature;
  String? _saveOperationId;
  _PendingClassSave? _pendingMutation;

  bool get _editing => widget.initialClass != null;
  bool get _editable =>
      widget.initialClass == null ||
      widget.initialClass!.status == ClassStatus.active;
  bool get _fieldsEnabled => _editable && !_busy && !_mutationAttempted;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialClass;
    _classId = initial?.id ?? _uuid.v4();
    _name.text = initial?.name ?? '';
    _startDate.text = initial?.startDate ?? '';
    _endDate.text = initial?.endDate ?? '';
    _teacherChoice = initial?.teacherContactId ?? _noTeacher;
    _loadTeachers();
  }

  @override
  void didUpdateWidget(covariant ClassForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId) {
      _teachers = const [];
      _loadTeachers();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _startDate.dispose();
    _endDate.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _loadingTeachers = true;
      _teacherError = null;
    });
    try {
      final teachers = [
        ...await widget.repository.listEligibleClassTeachers(
          congregationId: widget.congregationId,
        ),
      ];
      final currentTeacherId = widget.initialClass?.teacherContactId;
      if (currentTeacherId != null &&
          !teachers.any((teacher) => teacher.id == currentTeacherId)) {
        try {
          final current = await widget.repository.getTeacherContact(
            congregationId: widget.congregationId,
            contactId: currentTeacherId,
          );
          teachers.add(
            MinistryDirectoryEntry(
              id: current.id,
              name: current.name,
              normalizedName: current.name.toLowerCase(),
              scope: 'congregation',
              congregationId: current.congregationId,
              roleCode: 'teacher',
              phoneE164: current.phoneE164,
              birthDate: current.birthDate,
              archivedAt: null,
              revision: current.revision,
              email: null,
              userAccessId: null,
            ),
          );
        } on DataFailure {
          _teacherError = 'O professor atual não está disponível. Escolha outro professor ou deixe a turma sem designação.';
          _teacherChoice = _noTeacher;
        }
      }
      if (!mounted) return;
      setState(() {
        _teachers = List.unmodifiable(teachers);
        _loadingTeachers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTeachers = false;
        _teacherError = 'Não foi possível carregar os professores.';
      });
    }
  }

  CalendarDate? _parseDate(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    try {
      return CalendarDate.parse(value);
    } on MinistryDataException {
      return null;
    }
  }

  String? _requiredDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe a data de início.';
    }
    try {
      CalendarDate.parse(value.trim());
      return null;
    } on MinistryDataException {
      return 'Use o formato AAAA-MM-DD.';
    }
  }

  String? _optionalDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      CalendarDate.parse(value.trim());
      return null;
    } on MinistryDataException {
      return 'Use o formato AAAA-MM-DD.';
    }
  }

  Future<void> _save() async {
    if (_busy || !_editable || !_form.currentState!.validate()) return;
    final start = _parseDate(_startDate)!;
    final end = _parseDate(_endDate);
    if (end != null && end.compareTo(start) < 0) {
      setState(
        () => _error =
            'A data de término deve ser igual ou posterior à data de início.',
      );
      return;
    }
    final teacherId = _teacherChoice == _noTeacher ? null : _teacherChoice;
    final name = _name.text.trim();
    final signature = jsonEncode({
      'id': _classId,
      'congregation_id': widget.congregationId,
      'name': name,
      'teacher_contact_id': teacherId,
      'start_date': start.toString(),
      'end_date': end?.toString(),
      'expected_revision': widget.initialClass?.revision,
    });
    final pending = _pendingMutation;
    if (pending != null && pending.signature != signature) {
      setState(() {
        _error = 'O envio anterior ainda está pendente. Tente novamente sem alterar os dados.';
      });
      return;
    }
    if (pending == null && _saveSignature != signature) {
      _saveSignature = signature;
      _saveOperationId = _uuid.v4();
    }
    final mutation =
        pending ??
        _PendingClassSave(
          signature: signature,
          operationId: _saveOperationId!,
          id: _classId,
          congregationId: widget.congregationId,
          name: name,
          teacherContactId: teacherId,
          startDate: start,
          endDate: end,
          expectedRevision: widget.initialClass?.revision,
        );
    setState(() {
      _busy = true;
      _mutationAttempted = true;
      _error = null;
    });
    try {
      final result = await widget.repository.saveClass(
        operationId: mutation.operationId,
        id: mutation.id,
        congregationId: mutation.congregationId,
        name: mutation.name,
        teacherContactId: mutation.teacherContactId,
        startDate: mutation.startDate,
        endDate: mutation.endDate,
        expectedRevision: mutation.expectedRevision,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _mutationAttempted = false;
        _pendingMutation = null;
      });
      final initial = widget.initialClass;
      widget.onSaved(
        MinistryClassSummary(
          id: result.id,
          name: mutation.name,
          status: initial?.status ?? ClassStatus.active,
          startDate: mutation.startDate.toString(),
          endDate: mutation.endDate?.toString(),
          revision: result.revision,
          teacherContactId: mutation.teacherContactId,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final ambiguous = _isAmbiguousMutationFailure(error);
      setState(() {
        _error = error is DataFailure && error.code == 'stale_revision'
            ? 'A turma foi alterada por outra pessoa. Atualize a lista antes de tentar novamente.'
            : ambiguous
            ? 'Não foi possível confirmar o salvamento. Tente novamente sem alterar os dados.'
            : 'Não foi possível salvar a turma. Confira os dados e tente novamente.';
        _busy = false;
        _mutationAttempted = ambiguous;
        _pendingMutation = ambiguous ? mutation : null;
      });
    }
  }

  bool _isAmbiguousMutationFailure(Object error) =>
      error is! DataFailure ||
      !const {'invalid', 'permission', 'stale_revision'}.contains(error.code);

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_mutationAttempted,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(_editing ? 'Editar turma' : 'Nova turma')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(UnifiedSpace.x4),
              children: [
                Base44PageHeading(
                  title: _editing ? 'Editar turma' : 'Nova turma',
                  icon: Icons.groups_outlined,
                  subtitle: 'As alterações ficam registradas na congregação selecionada.',
                ),
                const SizedBox(height: UnifiedSpace.x4),
                Base44Panel(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('class-name'),
                          controller: _name,
                          enabled: _fieldsEnabled,
                          maxLength: 200,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Nome da turma',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            prefixIcon: Icon(Icons.groups_outlined),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: UnifiedSpace.x4,
                              vertical: UnifiedSpace.x4,
                            ),
                          ),
                          validator: (value) {
                            final name = value?.trim() ?? '';
                            if (name.isEmpty) return 'Informe o nome da turma.';
                            if (name.length > 200)
                              return 'Use até 200 caracteres.';
                            return null;
                          },
                        ),
                        const SizedBox(height: UnifiedSpace.fieldGap),
                        DropdownButtonFormField<String>(
                          key: const Key('class-teacher-dropdown'),
                          initialValue: _teacherChoice,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Professor',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            prefixIcon: const Icon(Icons.person_outline),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: UnifiedSpace.x4,
                              vertical: UnifiedSpace.x4,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: _noTeacher,
                              child: Text('Sem professor definido'),
                            ),
                            if (widget.initialClass?.teacherContactId != null &&
                                !_teachers.any(
                                  (teacher) =>
                                      teacher.id ==
                                      widget.initialClass!.teacherContactId,
                                ))
                              DropdownMenuItem(
                                value: widget.initialClass!.teacherContactId!,
                                child: Text(
                                  _loadingTeachers
                                      ? 'Carregando professor atual…'
                                      : 'Professor atual indisponível',
                                ),
                              ),
                            for (final teacher in _teachers)
                              DropdownMenuItem(
                                value: teacher.id,
                                child: Text(teacher.name, softWrap: true),
                              ),
                          ],
                          onChanged:
                              _busy ||
                                  _mutationAttempted ||
                                  _loadingTeachers ||
                                  !_editable
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _teacherChoice = value);
                                  }
                                },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: UnifiedSpace.x4,
                            top: UnifiedSpace.x2,
                          ),
                          child: Text(
                            _loadingTeachers ? 'Carregando professores…' : 'Apenas professores ativos desta congregação.',
                          ),
                        ),
                        if (_teacherError != null) ...[
                          const SizedBox(height: UnifiedSpace.x2),
                          Text(
                            _teacherError!,
                            style: const TextStyle(
                              color: UnifiedColors.warning,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _loadingTeachers
                                  ? null
                                  : _loadTeachers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar carregar novamente'),
                            ),
                          ),
                        ],
                        const SizedBox(height: UnifiedSpace.fieldGap),
                        TextFormField(
                          key: const Key('class-start-date'),
                          controller: _startDate,
                          enabled: _fieldsEnabled,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Data de início',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            hintText: 'AAAA-MM-DD',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: UnifiedSpace.x4,
                              vertical: UnifiedSpace.x4,
                            ),
                          ),
                          validator: _requiredDate,
                        ),
                        const SizedBox(height: UnifiedSpace.fieldGap),
                        TextFormField(
                          key: const Key('class-end-date'),
                          controller: _endDate,
                          enabled: _fieldsEnabled,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Data de término',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            hintText: 'AAAA-MM-DD',
                            prefixIcon: Icon(Icons.event_available_outlined),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: UnifiedSpace.x4,
                              vertical: UnifiedSpace.x4,
                            ),
                          ),
                          validator: _optionalDate,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: UnifiedSpace.x2),
                          Text(
                            _error!,
                            style: const TextStyle(color: UnifiedColors.error),
                          ),
                        ],
                        const SizedBox(height: UnifiedSpace.sectionGap),
                        Wrap(
                          spacing: UnifiedSpace.x2,
                          runSpacing: UnifiedSpace.x2,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _busy || _mutationAttempted
                                  ? null
                                  : widget.onCancel,
                              child: const Text('Cancelar'),
                            ),
                            FilledButton.icon(
                              onPressed: _busy || !_editable ? null : _save,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _busy
                                    ? 'Salvando…'
                                    : _pendingMutation == null
                                    ? 'Salvar turma'
                                    : 'Tentar novamente',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PendingClassSave {
  const _PendingClassSave({
    required this.signature,
    required this.operationId,
    required this.id,
    required this.congregationId,
    required this.name,
    required this.teacherContactId,
    required this.startDate,
    required this.endDate,
    required this.expectedRevision,
  });

  final String signature;
  final String operationId;
  final String id;
  final String congregationId;
  final String name;
  final String? teacherContactId;
  final CalendarDate startDate;
  final CalendarDate? endDate;
  final int? expectedRevision;
}
