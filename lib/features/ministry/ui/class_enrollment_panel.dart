import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';

class ClassEnrollmentPanel extends StatefulWidget {
  const ClassEnrollmentPanel({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.classId,
    required this.classStartDate,
    required this.classEndDate,
    required this.onChanged,
  });

  final MinistryRepository repository;
  final String congregationId;
  final String classId;
  final String classStartDate;
  final String? classEndDate;
  final VoidCallback onChanged;

  @override
  State<ClassEnrollmentPanel> createState() => _ClassEnrollmentPanelState();
}

class _ClassEnrollmentPanelState extends State<ClassEnrollmentPanel> {
  final _uuid = const Uuid();
  final _query = TextEditingController();
  List<ClassStudentEntry> _entries = const [];
  List<MinistryPersonSummary> _people = const [];
  String? _selectedPersonId;
  bool _loading = true;
  bool _searching = false;
  bool _busy = false;
  String? _error;
  String? _enrollSignature;
  String? _enrollOperationId;
  String? _enrollId;
  String? _closeSignature;
  String? _closeOperationId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ClassEnrollmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId ||
        oldWidget.classId != widget.classId) {
      _entries = const [];
      _people = const [];
      _selectedPersonId = null;
      _enrollSignature = null;
      _enrollOperationId = null;
      _enrollId = null;
      _closeSignature = null;
      _closeOperationId = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listClassStudents(
        congregationId: widget.congregationId,
        classId: widget.classId,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _entries = page.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _searchPeople() async {
    final query = _query.text.trim();
    if (query.isEmpty || query.length > 200) {
      setState(() => _error = 'Informe um nome para buscar pessoas.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listPeople(
        congregationId: widget.congregationId,
        namePrefix: query,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _people = page.items;
        _selectedPersonId = null;
        _searching = false;
        if (page.items.isEmpty) _error = 'Nenhuma pessoa encontrada.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _enroll() async {
    final personId = _selectedPersonId;
    if (_busy || personId == null) return;
    final startDate = CalendarDate.parse(widget.classStartDate);
    final signature = jsonEncode([
      widget.congregationId,
      widget.classId,
      personId,
      startDate.toString(),
    ]);
    if (_enrollSignature != signature) {
      _enrollSignature = signature;
      _enrollOperationId = _uuid.v4();
      _enrollId = _uuid.v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.enrollStudent(
        operationId: _enrollOperationId!,
        id: _enrollId!,
        congregationId: widget.congregationId,
        classId: widget.classId,
        personId: personId,
        startDate: startDate,
      );
      _enrollSignature = null;
      _enrollOperationId = null;
      _enrollId = null;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _selectedPersonId = null;
        _people = const [];
      });
      widget.onChanged();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _chooseClose(ClassStudentEntry entry) async {
    if (_busy) return;
    final status = await showDialog<EnrollmentStatus>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerrar matrícula'),
        content: Text(
          'Como deseja encerrar a participação de ${entry.student.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, EnrollmentStatus.withdrawn),
            child: const Text('Registrar desistência'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, EnrollmentStatus.completed),
            child: const Text('Concluir participação'),
          ),
        ],
      ),
    );
    if (status != null && mounted) await _close(entry, status);
  }

  Future<void> _close(ClassStudentEntry entry, EnrollmentStatus status) async {
    final enrollment = entry.enrollment;
    final today = DateTime.now();
    final now = CalendarDate(today.year, today.month, today.day);
    final start = enrollment.startDate;
    final endBound = widget.classEndDate == null
        ? null
        : CalendarDate.parse(widget.classEndDate!);
    final endDate = now.compareTo(start) < 0
        ? start
        : endBound != null && endBound.compareTo(now) < 0
        ? endBound
        : now;
    final signature = jsonEncode([
      enrollment.id,
      widget.congregationId,
      status.wire,
      endDate.toString(),
      enrollment.revision,
    ]);
    if (_closeSignature != signature) {
      _closeSignature = signature;
      _closeOperationId = _uuid.v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.closeEnrollment(
        operationId: _closeOperationId!,
        enrollmentId: enrollment.id,
        congregationId: widget.congregationId,
        status: status,
        endDate: endDate,
        startDate: start,
        expectedRevision: enrollment.revision,
      );
      _closeSignature = null;
      _closeOperationId = null;
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  String _message(Object error) {
    if (error is DataFailure) {
      return switch (error.code) {
        'class_capacity' => 'Esta turma atingiu o limite de 100 matrículas.',
        'active_enrollment' ||
        'academic_conflict' ||
        'record_exists' => 'Esta pessoa já possui matrícula ativa nesta turma.',
        'person_not_found' =>
          'A pessoa não está disponível na congregação selecionada.',
        'academic_invalid' || 'class_not_active' => 'A matrícula não foi aceita. A turma pode ter sido encerrada ou atingido o limite. Atualize os dados e tente novamente.',
        'forbidden' || 'invalid_congregation' =>
          'A congregação selecionada não está disponível para sua conta.',
        'stale_revision' => 'A matrícula foi alterada por outra pessoa. Atualize a turma e tente novamente.',
        _ => 'Não foi possível concluir a operação. Tente novamente.',
      };
    }
    return 'Não foi possível carregar os dados. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) => Base44Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Matrículas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: UnifiedSpace.x3),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Carregando matrículas',
            ),
          )
        else if (_entries.isEmpty)
          const Text('Nenhum aluno matriculado nesta turma.'),
        for (final entry in _entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.student.name),
            subtitle: Text('Matriculado desde ${entry.enrollment.startDate}'),
            trailing: TextButton(
              key: Key('close-enrollment-${entry.enrollment.id}'),
              onPressed: _busy ? null : () => _chooseClose(entry),
              child: const Text('Encerrar'),
            ),
          ),
        const SizedBox(height: UnifiedSpace.x3),
        Text(
          'Matricular pessoa',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UnifiedSpace.x2),
        TextField(
          key: const Key('enrollment-person-query'),
          controller: _query,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Nome da pessoa',
            hintText: 'Busque no cadastro da congregação',
            counterText: '',
          ),
          onSubmitted: (_) => _searchPeople(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('enrollment-search-button'),
            onPressed: _searching || _busy ? null : _searchPeople,
            icon: _searching
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Buscar pessoa'),
          ),
        ),
        if (_people.isNotEmpty) ...[
          const SizedBox(height: UnifiedSpace.x2),
          DropdownButtonFormField<String>(
            key: const Key('enrollment-person-search'),
            initialValue: _selectedPersonId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Pessoa'),
            items: [
              for (final person in _people)
                DropdownMenuItem(
                  value: person.id,
                  child: Text(person.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _selectedPersonId = value),
          ),
          const SizedBox(height: UnifiedSpace.x2),
          FilledButton.icon(
            key: const Key('enroll-person-button'),
            onPressed: _busy || _selectedPersonId == null ? null : _enroll,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Matricular'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: UnifiedSpace.x2),
          Text(_error!, style: const TextStyle(color: UnifiedColors.error)),
          TextButton(onPressed: _load, child: const Text('Atualizar')),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: UnifiedSpace.x2),
            child: LinearProgressIndicator(
              semanticsLabel: 'Salvando matrícula',
            ),
          ),
      ],
    ),
  );
}
