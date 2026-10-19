import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../data/ministry_browser_repository.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';

class SessionForm extends StatefulWidget {
  const SessionForm({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.classSummary,
    this.existingSessions = const [],
  });
  final MinistryRepository repository;
  final String congregationId;
  final MinistryClassSummary classSummary;
  final List<MinistrySessionSummary> existingSessions;
  @override
  State<SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<SessionForm> {
  final _uuid = const Uuid();
  final _date = TextEditingController();
  final _topic = TextEditingController();
  _PendingCreate? _pending;
  bool _busy = false;
  String? _error;

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

  Future<void> _save() async {
    if (_busy) return;
    final date = _parseDate(_date.text);
    if (date == null) {
      setState(() => _error = 'Informe uma data válida.');
      return;
    }
    if (widget.classSummary.status != ClassStatus.active) {
      setState(() => _error = 'Esta turma não está ativa.');
      return;
    }
    if (widget.existingSessions.any(
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
      );
      if (identical(_pending, request)) _pending = null;
      if (mounted) Navigator.of(context).pop(request.id);
    } catch (error) {
      if (!mounted) return;
      if (error is DataFailure &&
          const {
            'invalid',
            'permission',
            'forbidden',
            'invalid_congregation',
            'class_not_active',
            'academic_invalid',
            'academic_conflict',
            'operation_conflict',
          }.contains(error.code) &&
          identical(_pending, request))
        _pending = null;
      setState(() {
        _busy = false;
        _error = error is DataFailure && error.code == 'academic_conflict'
            ? 'Já existe uma aula nesta data.'
            : 'Não foi possível salvar a aula. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nova aula')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Turma: ${widget.classSummary.name}'),
          TextField(
            key: const Key('session-date'),
            controller: _date,
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
    this.signature,
  );
  final String operationId, id, congregationId, classId, signature;
  final CalendarDate date;
  final String? topic;
}
