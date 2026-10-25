import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/business_calendar.dart';
import '../../domain/models.dart';
import '../converts/convert_form.dart';
import 'intake_models.dart';
import 'pending_submission_repository.dart';

const _allCongregations = '__all_congregations__';

/// Protected review queue. AccessScope is a UI boundary; T5 rechecks each call.
class PendingReviewPage extends StatefulWidget {
  const PendingReviewPage({
    super.key,
    required this.repository,
    required this.scope,
    required this.congregations,
    this.onScopeRefresh,
    this.now = DateTime.now,
  });

  final PendingSubmissionRepository repository;
  final AccessScope scope;
  final List<Congregation> congregations;
  final Future<void> Function()? onScopeRefresh;
  final DateTime Function() now;

  @override
  State<PendingReviewPage> createState() => _PendingReviewPageState();
}

class _PendingReviewPageState extends State<PendingReviewPage> {
  List<PendingSubmissionSummary> _items = const [];
  String? _nextCursor;
  String? _selectedCongregationId;
  PendingSubmissionDetail? _detail;
  bool _loading = false;
  bool _loadingDetail = false;
  bool _busy = false;
  bool _unknownOutcome = false;
  String? _error;
  String? _decisionError;
  String? _operationId;
  PendingReviewDecision? _frozenDecision;
  Map<String, Object?>? _frozenDraft;
  int _requestSequence = 0;

  bool get _authorized =>
      widget.scope.isGlobalManager || widget.scope.congregationIds.isNotEmpty;

  List<Congregation> get _availableCongregations => [
    for (final congregation in widget.congregations)
      if (congregation.archivedAt == null &&
          (widget.scope.isGlobalManager ||
              widget.scope.congregationIds.contains(congregation.id)))
        congregation,
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.scope.isGlobalManager &&
        widget.scope.congregationIds.length == 1) {
      _selectedCongregationId = widget.scope.congregationIds.single;
    }
    if (_authorized &&
        (widget.scope.isGlobalManager || _selectedCongregationId != null)) {
      unawaited(_loadQueue());
    }
  }

  @override
  void didUpdateWidget(covariant PendingReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _clearProtectedState();
      if (!widget.scope.isGlobalManager &&
          widget.scope.congregationIds.length == 1) {
        _selectedCongregationId = widget.scope.congregationIds.single;
      }
      if (_authorized &&
          (widget.scope.isGlobalManager || _selectedCongregationId != null)) {
        unawaited(_loadQueue());
      }
    }
  }

  Future<void> _loadQueue({String? cursor}) async {
    final scopeId = _selectedCongregationId;
    if (_unknownOutcome ||
        !_authorized ||
        (!widget.scope.isGlobalManager && scopeId == null)) {
      return;
    }
    if (scopeId != null &&
        !widget.scope.isGlobalManager &&
        !widget.scope.congregationIds.contains(scopeId)) {
      _clearProtectedState();
      return;
    }
    final sequence = ++_requestSequence;
    setState(() {
      _loading = true;
      _error = null;
      if (cursor == null) {
        _items = const [];
        _nextCursor = null;
        _detail = null;
      }
    });
    try {
      final page = await widget.repository.list(
        congregationId: scopeId,
        cursor: cursor,
      );
      if (!mounted || sequence != _requestSequence) return;
      if (page.items.any((item) => !_canSee(item.congregationId))) {
        throw const DataFailure('permission');
      }
      setState(() {
        _items = cursor == null ? page.items : [..._items, ...page.items];
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (!mounted || sequence != _requestSequence) return;
      _clearPageData();
      if (error is DataFailure &&
          (error.code == 'permission' || error.code == 'stale')) {
        unawaited(widget.onScopeRefresh?.call());
      }
      setState(() {
        _error = 'Não foi possível carregar as solicitações pendentes.';
      });
    } finally {
      if (mounted && sequence == _requestSequence) {
        setState(() => _loading = false);
      }
    }
  }

  bool _canSee(String congregationId) {
    if (widget.scope.isGlobalManager) {
      return _availableCongregations.any((item) => item.id == congregationId) &&
          (_selectedCongregationId == null ||
              _selectedCongregationId == congregationId);
    }
    return widget.scope.congregationIds.contains(congregationId) &&
        _availableCongregations.any((item) => item.id == congregationId) &&
        _selectedCongregationId == congregationId;
  }

  Future<void> _open(PendingSubmissionSummary summary) async {
    if (!_canSee(summary.congregationId)) return;
    final sequence = ++_requestSequence;
    setState(() {
      _loadingDetail = true;
      _detail = null;
      _decisionError = null;
      _clearOperation();
    });
    try {
      final detail = await widget.repository.get(summary.id);
      if (!mounted || sequence != _requestSequence) return;
      if (!_canSee(detail.summary.congregationId) ||
          detail.summary.congregationId != summary.congregationId) {
        throw const DataFailure('permission');
      }
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted || sequence != _requestSequence) return;
      _clearPageData();
      setState(() {
        _error = 'Não foi possível abrir esta solicitação. Atualize a fila.';
      });
      if (error is DataFailure &&
          (error.code == 'permission' || error.code == 'stale')) {
        unawaited(widget.onScopeRefresh?.call());
      }
    } finally {
      if (mounted && sequence == _requestSequence) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  void _backToQueue() {
    setState(() {
      _detail = null;
      _decisionError = null;
      _clearOperation();
    });
  }

  void _selectCongregation(String? value) {
    if (_unknownOutcome || _busy) return;
    final selected = value == _allCongregations ? null : value;
    if (selected != null &&
        !_availableCongregations.any((item) => item.id == selected)) {
      return;
    }
    if (!widget.scope.isGlobalManager && selected == null) return;
    setState(() {
      _selectedCongregationId = selected;
      _clearPageData();
      _clearOperation();
    });
    unawaited(_loadQueue());
  }

  void _clearOperation() {
    _unknownOutcome = false;
    _operationId = null;
    _frozenDecision = null;
    _frozenDraft = null;
    _busy = false;
  }

  void _clearPageData() {
    _items = const [];
    _nextCursor = null;
    _detail = null;
    _loadingDetail = false;
    _clearOperation();
  }

  void _clearProtectedState() {
    _requestSequence++;
    if (mounted) {
      setState(() {
        _clearPageData();
        _error = null;
        _decisionError = null;
      });
    } else {
      _clearPageData();
    }
  }

  Future<void> _approve(ConvertDraft draft) async {
    final detail = _detail;
    if (detail == null || _busy) return;
    if (draft.congregationId != detail.summary.congregationId) {
      setState(
        () => _decisionError =
            'A congregação desta solicitação não pode ser alterada.',
      );
      return;
    }
    final publicDraft = PublicIntakeDraft.fromConvertDraft(draft).toJson();
    final operationId = _operationId ?? const Uuid().v4();
    setState(() {
      _busy = true;
      _operationId = operationId;
      _frozenDecision = PendingReviewDecision.approve;
      _frozenDraft = publicDraft;
      _decisionError = null;
    });
    await _sendDecision(
      operationId,
      PendingReviewDecision.approve,
      publicDraft,
    );
  }

  Future<void> _reject() async {
    final detail = _detail;
    if (detail == null || _busy || _unknownOutcome) return;
    final operationId = const Uuid().v4();
    setState(() {
      _busy = true;
      _operationId = operationId;
      _frozenDecision = PendingReviewDecision.reject;
      _frozenDraft = null;
      _decisionError = null;
    });
    await _sendDecision(operationId, PendingReviewDecision.reject, null);
  }

  Future<void> _retryUnknown() async {
    final operationId = _operationId;
    final decision = _frozenDecision;
    final detail = _detail;
    if (!_unknownOutcome ||
        _busy ||
        operationId == null ||
        decision == null ||
        detail == null) {
      return;
    }
    setState(() => _busy = true);
    await _sendDecision(operationId, decision, _frozenDraft);
  }

  Future<void> _sendDecision(
    String operationId,
    PendingReviewDecision decision,
    Map<String, Object?>? draft,
  ) async {
    final detail = _detail;
    if (detail == null) return;
    try {
      await widget.repository.review(
        operationId: operationId,
        id: detail.summary.id,
        expectedRevision: detail.summary.revision,
        decision: decision,
        draft: draft,
      );
      if (!mounted || _detail?.summary.id != detail.summary.id) return;
      setState(() {
        _items = _items.where((item) => item.id != detail.summary.id).toList();
        _detail = null;
        _decisionError = null;
        _clearOperation();
      });
    } on PendingReviewFailure catch (error) {
      if (!mounted) return;
      if (error.code == 'stale' || error.code == 'permission') {
        _clearProtectedState();
        setState(() => _error = 'Seu acesso mudou. Atualize a página.');
        unawaited(widget.onScopeRefresh?.call());
        return;
      }
      setState(() {
        _busy = false;
        _unknownOutcome = error.outcomeUnknown;
        if (!error.outcomeUnknown) {
          _operationId = null;
          _frozenDecision = null;
          _frozenDraft = null;
        }
        _decisionError = error.outcomeUnknown
            ? 'O resultado ainda é desconhecido. Tente novamente para confirmar a mesma decisão.'
            : 'Não foi possível concluir. Seus dados foram mantidos para correção.';
      });
    } on DataFailure catch (error) {
      if (!mounted) return;
      if (error.code == 'stale' || error.code == 'permission') {
        _clearProtectedState();
        setState(() => _error = 'Seu acesso mudou. Atualize a página.');
        unawaited(widget.onScopeRefresh?.call());
      } else {
        setState(() {
          _busy = false;
          _operationId = null;
          _frozenDecision = null;
          _frozenDraft = null;
          _decisionError = 'Revise os dados e tente novamente.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _unknownOutcome = true;
        _decisionError = 'O resultado ainda é desconhecido. Tente novamente para confirmar a mesma decisão.';
      });
    }
  }

  ConvertRecord _recordFor(PendingSubmissionDetail detail) {
    final draft = detail.draft;
    final person = Map<String, Object?>.from(draft['person']! as Map);
    final convert = Map<String, Object?>.from(draft['convert']! as Map);
    final address = person['address'] is Map
        ? Map<String, Object?>.from(person['address']! as Map)
        : null;
    final identity = CanonicalPersonIdentity(
      name: person['name']! as String,
      phone: person['phone'] as String?,
      birthDate: person['birth_date'] == null
          ? null
          : DateOnly.parse(person['birth_date']! as String),
      address: address,
    );
    return ConvertRecord(
      id: detail.summary.id,
      internalId: '',
      name: identity.name,
      landmark: convert['landmark']! as String,
      gender: Gender.fromWire(convert['gender']! as String),
      conversionDate: DateOnly.parse(convert['conversion_date']! as String),
      worshipType: convert['worship_type']! as String,
      congregationId: detail.summary.congregationId,
      address: address?['street'] as String?,
      phone: identity.phone,
      age: convert['age'] as int?,
      convertRevision: detail.summary.revision,
      personIdentity: identity,
    );
  }

  String _expiryText(DateTime expiresAt) {
    final difference = expiresAt.difference(widget.now()).inDays;
    if (difference <= 0) return 'Expira em menos de um dia';
    return 'Expira em $difference ${difference == 1 ? 'dia' : 'dias'}';
  }

  Widget _filter() {
    if (!widget.scope.isGlobalManager && _availableCongregations.length <= 1) {
      final name = _availableCongregations.firstOrNull?.name;
      return Text(name ?? 'Congregação autorizada');
    }
    return DropdownButtonFormField<String>(
      key: const ValueKey('pending-congregation-filter'),
      initialValue:
          _selectedCongregationId ??
          (widget.scope.isGlobalManager ? _allCongregations : null),
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Filtrar congregação'),
      items: [
        if (widget.scope.isGlobalManager)
          const DropdownMenuItem(
            value: _allCongregations,
            child: Text('Todas as congregações'),
          ),
        for (final congregation in _availableCongregations)
          DropdownMenuItem(
            value: congregation.id,
            child: Text(congregation.name),
          ),
      ],
      onChanged: _loading || _busy || _unknownOutcome
          ? null
          : _selectCongregation,
    );
  }

  Widget _queue() {
    if (_loading) {
      return Expanded(
        child: Center(
          child: Semantics(
            label: 'Carregando solicitações pendentes',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_error != null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(
                key: const ValueKey('pending-refresh'),
                onPressed: () => _loadQueue(),
                child: const Text('Atualizar lista'),
              ),
            ],
          ),
        ),
      );
    }
    if (!widget.scope.isGlobalManager && _selectedCongregationId == null) {
      return const Expanded(
        child: Center(child: Text('Selecione uma congregação autorizada.')),
      );
    }
    if (_items.isEmpty) {
      return const Expanded(
        child: Center(child: Text('Nenhuma solicitação pendente.')),
      );
    }
    return Expanded(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Solicitações pendentes nesta página: ${_items.length}',
            ),
          ),
          for (final item in _items)
            Card(
              child: ListTile(
                key: ValueKey('pending-item-${item.id}'),
                title: Text(item.name),
                subtitle: Text(
                  '${item.congregationName} · ${_expiryText(item.expiresAt)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _loadingDetail ? null : () => _open(item),
              ),
            ),
          if (_nextCursor != null)
            TextButton(
              key: const ValueKey('pending-next-page'),
              onPressed: _loading
                  ? null
                  : () => _loadQueue(cursor: _nextCursor),
              child: const Text('Próximas solicitações'),
            ),
        ],
      ),
    );
  }

  Widget _details() {
    final detail = _detail;
    if (_loadingDetail) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }
    if (detail == null) return _queue();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${detail.summary.congregationName} · ${_expiryText(detail.summary.expiresAt)}',
          ),
          if (_decisionError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(liveRegion: true, child: Text(_decisionError!)),
            ),
          if (_unknownOutcome)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _retryUnknown,
                child: Text(_busy ? 'Confirmando…' : 'Tentar novamente'),
              ),
            ),
          Expanded(
            child: ConvertForm(
              key: ValueKey('pending-form-${detail.summary.id}'),
              initial: _recordFor(detail),
              congregations: _availableCongregations
                  .where((item) => item.id == detail.summary.congregationId)
                  .toList(growable: false),
              allowPhotos: false,
              allowCongregationChange: false,
              submitLabel: 'Aprovar cadastro',
              now: widget.now,
              submissionLocked: _busy || _unknownOutcome,
              onSubmit: _approve,
              onCancel: _backToQueue,
            ),
          ),
          TextButton(
            onPressed: _busy || _unknownOutcome ? null : _reject,
            child: Text(_busy ? 'Processando…' : 'Rejeitar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Scaffold(
        body: Center(
          child: Text('Você não tem acesso às solicitações pendentes.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendentes'),
        leading: _detail == null
            ? null
            : IconButton(
                tooltip: 'Voltar à fila',
                onPressed: _busy || _unknownOutcome ? null : _backToQueue,
                icon: const Icon(Icons.arrow_back),
              ),
        actions: [
          IconButton(
            key: const ValueKey('pending-refresh-button'),
            tooltip: 'Atualizar fila',
            onPressed: _loading || _busy || _unknownOutcome
                ? null
                : () => _loadQueue(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filter(),
              const SizedBox(height: 12),
              _detail == null ? _queue() : _details(),
            ],
          ),
        ),
      ),
    );
  }
}
