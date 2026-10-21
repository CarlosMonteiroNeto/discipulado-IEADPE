import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../data/ministry_browser_repository.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';

/// Result returned to the session list after the form closes.
class SessionFormResult {
  const SessionFormResult.created(String this.sessionId) : conflict = false;
  const SessionFormResult.conflict() : sessionId = null, conflict = true;

  final String? sessionId;
  final bool conflict;
}

class SessionForm extends StatefulWidget {
  const SessionForm({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.classSummary,
    this.existingSessions = const [],
    this.replacesSessionId,
    this.initialDate,
  });
  final MinistryRepository repository;
  final String congregationId;
  final MinistryClassSummary classSummary;
  final List<MinistrySessionSummary> existingSessions;
  final String? replacesSessionId;
  final CalendarDate? initialDate;
  bool get isReplacement => replacesSessionId != null;
  @override
  State<SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<SessionForm> {
  final _uuid = const Uuid();
  late final TextEditingController _date;
  final _topic = TextEditingController();
  _PendingCreate? _pending;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = TextEditingController(
      text: widget.initialDate == null ? '' : _displayDate(widget.initialDate!),
    );
  }

  @override
  void dispose() {
    _date.dispose();
    _topic.dispose();
    super.dispose();
  }

  CalendarDate? _parseDate(String value) {
    final text = value.trim();
    try {
      return CalendarDate.parse(
        text.contains('/') ? text.split('/').reversed.join('-') : text,
      );
    } catch (_) {
      return null;
    }
  }

  String _displayDate(CalendarDate date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _save() async {
    if (_busy) return;
    final date = _parseDate(_date.text);
    if (date == null) {
      setState(() => _error = 'Informe uma data válida.');
      return;
    }
    final fixedDate = widget.initialDate;
    if (widget.isReplacement != (fixedDate != null) ||
        (fixedDate != null && date.compareTo(fixedDate) != 0)) {
      setState(
        () => _error = 'A substituta precisa manter a mesma turma e a mesma data da aula cancelada.',
      );
      return;
    }
    if (widget.classSummary.status != ClassStatus.active) {
      setState(() => _error = 'Esta turma não está ativa.');
      return;
    }
    if (!widget.isReplacement &&
        widget.existingSessions.any(
          (item) =>
              item.date.compareTo(date) == 0 &&
              item.status != SessionStatus.canceled,
        )) {
      setState(() => _error = 'Já existe uma aula nesta data.');
      return;
    }
    final signature = jsonEncode([
      widget.congregationId,
      widget.classSummary.id,
      date.toString(),
      _topic.text.trim(),
      widget.replacesSessionId,
    ]);
    final pending = _pending;
    if (pending != null && pending.signature != signature) {
      setState(
        () => _error =
            'Repita ou resolva a aula pendente antes de alterar os dados.',
      );
      return;
    }
    final request =
        pending ??
        _PendingCreate(
          _uuid.v4(),
          _uuid.v4(),
          widget.congregationId,
          widget.classSummary.id,
          date,
          _topic.text.trim().isEmpty ? null : _topic.text.trim(),
          widget.replacesSessionId,
          signature,
        );
    _pending ??= request;
    await _submit(request);
  }

  Future<void> _submit(_PendingCreate request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createSession(
        operationId: request.operationId,
        id: request.id,
        congregationId: request.congregationId,
        classId: request.classId,
        date: request.date,
        topic: request.topic,
        replacesSessionId: request.replacesSessionId,
      );
      if (identical(_pending, request)) _pending = null;
      if (mounted) {
        Navigator.of(context).pop(SessionFormResult.created(request.id));
      }
    } catch (error) {
      if (!mounted) return;
      final code = error is DataFailure ? error.code : null;
      final ambiguousReplacement =
          widget.isReplacement &&
          (code == 'invalid' || code == 'operation_conflict');
      if (code != null &&
          !ambiguousReplacement &&
          const {
            'invalid',
            'permission',
            'forbidden',
            'invalid_congregation',
            'class_not_active',
            'academic_invalid',
            'academic_conflict',
            'operation_conflict',
          }.contains(code) &&
          identical(_pending, request)) {
        _pending = null;
      }
      if (widget.isReplacement &&
          (code == 'academic_conflict' || code == 'academic_invalid')) {
        Navigator.of(context).pop(const SessionFormResult.conflict());
        return;
      }
      setState(() {
        _busy = false;
        _error = ambiguousReplacement
            ? 'Não foi possível confirmar se a substituta foi registrada. '
                  '“Repetir criação pendente” reenvia exatamente a mesma '
                  'solicitação.'
            : code == 'academic_conflict'
            ? 'Já existe uma aula nesta data.'
            : 'Não foi possível salvar a aula. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.isReplacement ? 'Substituir aula cancelada' : 'Nova aula',
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Turma: ${widget.classSummary.name}'),
          if (widget.isReplacement) ...[
            const SizedBox(height: 8),
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'A substituta mantém a turma e a data da aula cancelada. '
                  'A lista de alunos será congelada no primeiro salvamento e '
                  'pode refletir matrículas atuais.',
                ),
              ),
            ),
          ],
          TextField(
            key: const Key('session-date'),
            controller: _date,
            readOnly: widget.isReplacement,
            decoration: const InputDecoration(
              labelText: 'Data',
              helperText: 'Formato: DD/MM/AAAA',
              helperMaxLines: 2,
            ),
            keyboardType: TextInputType.datetime,
          ),
          TextField(
            key: const Key('session-topic'),
            controller: _topic,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Tema (opcional)'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Salvar'),
          ),
          if (_pending != null)
            TextButton(
              key: const Key('retry-pending-session-create'),
              onPressed: _busy ? null : () => _submit(_pending!),
              child: const Text('Repetir criação pendente'),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}

class _PendingCreate {
  const _PendingCreate(
    this.operationId,
    this.id,
    this.congregationId,
    this.classId,
    this.date,
    this.topic,
    this.replacesSessionId,
    this.signature,
  );
  final String operationId, id, congregationId, classId, signature;
  final CalendarDate date;
  final String? topic;
  final String? replacesSessionId;
}
