import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../data/ministry_browser_repository.dart';
import '../data/ministry_handoff_repository.dart';
import '../data/ministry_repository.dart';

enum _RetryAction { referrals, candidates, classes, promotion, enrollment }

class ConvertHandoffPage extends StatefulWidget {
  const ConvertHandoffPage({
    super.key,
    required this.congregationId,
    required this.canPromote,
    required this.handoff,
    required this.browser,
    required this.ministry,
    this.createOperationId,
  });
  final String congregationId;
  final bool canPromote;
  final MinistryHandoffRepository handoff;
  final MinistryBrowserRepository browser;
  final MinistryRepository ministry;
  final String Function()? createOperationId;
  @override
  State<ConvertHandoffPage> createState() => _ConvertHandoffPageState();
}

class _ConvertHandoffPageState extends State<ConvertHandoffPage> {
  final _uuid = const Uuid();
  final _search = TextEditingController();
  List<ConvertReferral> _referrals = const [];
  String? _referralCursor;
  bool _referralsLoaded = false;
  bool _referralsLoading = false;
  bool _referralsMoreLoading = false;
  List<MinistryClassSummary> _classes = const [];
  String? _classCursor;
  bool _classesLoaded = false;
  bool _classesLoading = false;
  bool _classesMoreLoading = false;
  List<HandoffStudentCandidate> _candidates = const [];
  String? _candidateCursor;
  bool _candidatesLoading = false;
  bool _candidatesMoreLoading = false;
  String? _candidatePrefix;
  ConvertReferral? _selected;
  HandoffStudentCandidate? _candidate;
  ConvertPromotionResult? _linked;
  String? _selectedClassId;
  String? _error;
  String? _notice;
  bool _busy = false;
  bool get _selectionLocked =>
      _busy ||
      _referralsLoading ||
      _referralsMoreLoading ||
      _candidatesLoading ||
      _candidatesMoreLoading ||
      _classesLoading ||
      _classesMoreLoading;
  _RetryAction? _retryAction;
  String? _retryCursor;
  String? _retryStudentId;
  final Map<String, String> _promotionOps = {};
  final Map<String, String> _enrollmentOps = {};

  @override
  void initState() {
    super.initState();
    if (widget.canPromote) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _newOperationId() => widget.createOperationId?.call() ?? _uuid.v4();
  void _load() => _loadReferrals();

  Future<void> _loadReferrals({String? cursor}) async {
    setState(() {
      _referralsLoading = cursor == null;
      _referralsMoreLoading = cursor != null;
      _error = null;
      _retryAction = _RetryAction.referrals;
      _retryCursor = cursor;
      if (cursor == null) {
        _referrals = const [];
        _referralCursor = null;
        _referralsLoaded = false;
      }
    });
    try {
      final page = await widget.handoff.listConvertReferrals(
        congregationId: widget.congregationId,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _referrals = [..._referrals, ...page.items];
        _referralCursor = page.nextCursor;
        _referralsLoaded = true;
        _referralsLoading = false;
        _referralsMoreLoading = false;
        _retryAction = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referralsLoading = false;
        _referralsMoreLoading = false;
        _error =
            'Não foi possível carregar os encaminhamentos. Tente novamente.';
      });
    }
  }

  Future<void> _loadClasses({String? cursor}) async {
    setState(() {
      _classesLoading = cursor == null;
      _classesMoreLoading = cursor != null;
      _error = null;
      _retryAction = _RetryAction.classes;
      _retryCursor = cursor;
      if (cursor == null) {
        _classes = const [];
        _classCursor = null;
        _classesLoaded = false;
      }
    });
    try {
      final page = await widget.browser.listClasses(
        congregationId: widget.congregationId,
        status: 'active',
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _classes = [..._classes, ...page.items];
        _classCursor = page.nextCursor;
        _classesLoaded = true;
        _classesLoading = false;
        _classesMoreLoading = false;
        _retryAction = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _classesLoading = false;
        _classesMoreLoading = false;
        _error = 'Não foi possível carregar as turmas. Tente novamente.';
      });
    }
  }

  Future<void> _retry() async {
    switch (_retryAction) {
      case _RetryAction.referrals:
        return _loadReferrals(cursor: _retryCursor);
      case _RetryAction.candidates:
        return _findCandidates(cursor: _retryCursor);
      case _RetryAction.classes:
        return _loadClasses(cursor: _retryCursor);
      case _RetryAction.promotion:
        return _promote(studentId: _retryStudentId);
      case _RetryAction.enrollment:
        return _enroll();
      case null:
        return;
    }
  }

  Future<void> _findCandidates({String? cursor}) async {
    if (_busy ||
        _candidatesLoading ||
        _candidatesMoreLoading ||
        _linked != null) {
      return;
    }
    final selected = _selected;
    final prefix = _candidatePrefix ?? _search.text.trim();
    if (selected == null || prefix.isEmpty) return;
    setState(() {
      _candidatesLoading = cursor == null;
      _candidatesMoreLoading = cursor != null;
      _error = null;
      _retryAction = _RetryAction.candidates;
      _retryCursor = cursor;
      if (cursor == null) {
        _candidate = null;
        _candidates = const [];
        _candidateCursor = null;
        _candidatePrefix = prefix;
      }
    });
    try {
      final page = await widget.handoff.listStudentCandidates(
        congregationId: selected.congregationId,
        namePrefix: prefix,
        limit: 20,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _candidates = [..._candidates, ...page.items];
        _candidateCursor = page.nextCursor;
        _candidatesLoading = false;
        _candidatesMoreLoading = false;
        _retryAction = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _candidatesLoading = false;
          _candidatesMoreLoading = false;
          _error = 'Não foi possível buscar alunos. Revise a conexão e tente novamente.';
        });
      }
    }
  }

  Future<void> _promote({String? studentId}) async {
    final selected = _selected;
    if (selected == null || !widget.canPromote) return;
    final draftKey = '${selected.convertId}:${studentId ?? 'create'}';
    final op = _promotionOps.putIfAbsent(draftKey, _newOperationId);
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _retryAction = _RetryAction.promotion;
      _retryStudentId = studentId;
    });
    try {
      final result = await widget.handoff.promote(
        operationId: op,
        convertId: selected.convertId,
        congregationId: selected.congregationId,
        studentId: studentId,
      );
      if (!mounted) return;
      setState(() {
        _linked = result;
        _busy = false;
        _retryAction = null;
        _notice = 'Vínculo confirmado. A matrícula é uma etapa separada.';
        _classes = const [];
        _classesLoaded = false;
      });
      await _loadClasses();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _retryAction = _RetryAction.promotion;
        _retryStudentId = studentId;
        _error = _friendly(error);
      });
    }
  }

  Future<void> _enroll() async {
    final linked = _linked;
    final classId = _selectedClassId;
    if (linked == null || classId == null) return;
    final key = '${linked.studentId}:$classId';
    final op = _enrollmentOps.putIfAbsent(key, _newOperationId);
    final enrollmentId = _enrollmentOps.putIfAbsent('$key:id', _newOperationId);
    final today = DateTime.now();
    final date =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _retryAction = _RetryAction.enrollment;
    });
    try {
      await widget.ministry.command(
        name: 'enroll_student',
        operationId: op,
        payload: {
          'id': enrollmentId,
          'congregation_id': linked.congregationId,
          'class_id': classId,
          'student_id': linked.studentId,
          'start_date': date,
        },
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _retryAction = null;
          _notice = 'Aluno vinculado e matriculado na turma selecionada.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _retryAction = _RetryAction.enrollment;
          _error = _friendly(error);
        });
      }
    }
  }

  String _friendly(Object error) => switch (error) {
    DataFailure(code: 'permission') =>
      'Seu acesso mudou. Atualize a sessão para continuar.',
    DataFailure(code: 'unavailable') => 'Serviço indisponível. O rascunho e o código de operação foram mantidos; tente novamente.',
    DataFailure(code: 'invalid') =>
      'O registro não está mais disponível para esta ação. Atualize a lista.',
    _ => 'Não foi possível concluir. O rascunho e o código de operação foram mantidos; tente novamente.',
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.canPromote) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Você não tem acesso ao encaminhamento de convertidos nesta congregação.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Encaminhar para o discipulado',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Revise os dados de referência e escolha criar um aluno ou vincular um aluno existente. Nenhuma matrícula é feita automaticamente.',
                ),
                const SizedBox(height: 16),
                _errorBanner(),
                _noticeBanner(),
                _referralList(),
                if (_selected != null) ...[
                  const SizedBox(height: 12),
                  _reviewCard(),
                  if (_linked == null) _candidateReview(),
                  if (_linked != null) _enrollmentCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() => _error == null
      ? const SizedBox.shrink()
      : Semantics(
          liveRegion: true,
          label: _error,
          child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!),
                  if (_retryAction != null)
                    TextButton(
                      onPressed: _busy ? null : _retry,
                      child: const Text('Tentar novamente'),
                    ),
                ],
              ),
            ),
          ),
        );
  Widget _noticeBanner() => _notice == null
      ? const SizedBox.shrink()
      : Semantics(
          liveRegion: true,
          label: _notice,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_notice!),
            ),
          ),
        );
  Widget _referralList() {
    if (_referralsLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Carregando encaminhamentos',
          ),
        ),
      );
    }
    if (!_referralsLoaded) return const SizedBox.shrink();
    if (_referrals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Não há novos encaminhamentos para esta congregação.'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Novos convertidos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final item in _referrals)
          Card(
            child: Semantics(
              button: true,
              label: 'Revisar ${item.name}',
              child: ListTile(
                key: Key('handoff-referral-${item.convertId}'),
                title: Text(item.name),
                subtitle: Text('Conversão: ${item.conversionDate}'),
                selected: _selected?.convertId == item.convertId,
                onTap: _selectionLocked
                    ? null
                    : () => setState(() {
                        _selected = item;
                        _candidate = null;
                        _linked = null;
                        _candidates = const [];
                        _error = null;
                        _notice = null;
                        _retryAction = null;
                        _candidatePrefix = null;
                        _candidateCursor = null;
                      }),
              ),
            ),
          ),
        if (_referralCursor != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy || _referralsMoreLoading
                  ? null
                  : () => _loadReferrals(cursor: _referralCursor),
              child: Text(
                _referralsMoreLoading
                    ? 'Carregando convertidos…'
                    : 'Carregar mais convertidos',
              ),
            ),
          ),
      ],
    );
  }

  Widget _reviewCard() {
    final referral = _selected!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Referência do convertido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(referral.name, style: Theme.of(context).textTheme.titleLarge),
            Text(
              'Telefone de referência: ${referral.phone ?? 'Não informado'}',
            ),
            Text(
              'Endereço de referência: ${referral.address ?? 'Não informado'}',
            ),
            Text('Data da conversão: ${referral.conversionDate}'),
            const SizedBox(height: 8),
            const Text(
              'Nome, telefone e endereço serão copiados como referência inicial. Alterações futuras ficam em cada módulo.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _candidateReview() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revisar aluno existente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextField(
            controller: _search,
            enabled:
                !_busy &&
                !_candidatesLoading &&
                !_candidatesMoreLoading &&
                _linked == null,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Buscar aluno pelo nome',
              helperText:
                  'A busca mostra somente alunos ativos desta congregação.',
            ),
            onSubmitted: (_) => _findCandidates(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy || _candidatesLoading ? null : _findCandidates,
            icon: const Icon(Icons.search),
            label: const Text('Buscar possíveis alunos'),
          ),
          if (_candidatesLoading)
            const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Buscando alunos',
              ),
            ),
          RadioGroup<String>(
            groupValue: _candidate?.studentId,
            onChanged: (value) {
              if (_busy || value == null) return;
              setState(() {
                _candidate = _candidates.firstWhere(
                  (item) => item.studentId == value,
                );
              });
            },
            child: Column(
              children: [
                for (final item in _candidates)
                  Card(
                    child: RadioListTile<String>(
                      value: item.studentId,
                      title: Text(item.name),
                      subtitle: Text(_candidateDetails(item)),
                      secondary: const Icon(Icons.person_search_outlined),
                    ),
                  ),
              ],
            ),
          ),
          if (_candidateCursor != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy || _candidatesMoreLoading
                    ? null
                    : () => _findCandidates(cursor: _candidateCursor),
                child: Text(
                  _candidatesMoreLoading
                      ? 'Carregando alunos…'
                      : 'Ver mais alunos',
                ),
              ),
            ),
          if (_candidate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Você selecionou ${_candidate!.name}. Os dados atuais do aluno serão preservados; apenas a origem deste vínculo ficará registrada.',
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _promote(studentId: _candidate?.studentId),
            child: Text(
              _candidate == null
                  ? 'Criar aluno a partir desta referência'
                  : 'Vincular ao aluno selecionado',
            ),
          ),
        ],
      ),
    ),
  );
  String _candidateDetails(HandoffStudentCandidate item) {
    final source = _selected!;
    final sourceAddress = source.address?.trim();
    final studentAddress = item.address?.street?.trim();
    final phone = item.phone ?? 'Não informado';
    final address = studentAddress ?? 'Não informado';
    final differs =
        item.name != source.name ||
        item.phone != source.phone ||
        (sourceAddress != null &&
            sourceAddress.isNotEmpty &&
            sourceAddress != studentAddress);
    final comparison = differs
        ? 'Há diferenças. Confirme a pessoa; os dados atuais serão preservados.'
        : 'Os dados conferem; confirme que é a mesma pessoa.';
    return 'Telefone atual: $phone · Endereço atual: $address. $comparison';
  }

  Widget _enrollmentCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Matrícula separada',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'O aluno já está vinculado ao convertido. Escolha uma turma ativa para fazer a matrícula explicitamente.',
          ),
          if (_classesLoading || (!_classesLoaded && _error == null))
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Carregando turmas',
                ),
              ),
            )
          else if (!_classesLoaded)
            const SizedBox.shrink()
          else if (_classes.isEmpty)
            const Text('Não há turmas ativas para matrícula.')
          else
            DropdownButtonFormField<String>(
              key: const Key('handoff-class-select'),
              initialValue: _selectedClassId,
              decoration: const InputDecoration(labelText: 'Turma'),
              items: [
                for (final item in _classes)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (value) => setState(() => _selectedClassId = value),
            ),
          if (_classCursor != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy || _classesMoreLoading
                    ? null
                    : () => _loadClasses(cursor: _classCursor),
                child: Text(
                  _classesMoreLoading
                      ? 'Carregando turmas…'
                      : 'Ver mais turmas',
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || _selectedClassId == null ? null : _enroll,
            icon: const Icon(Icons.how_to_reg),
            label: const Text('Matricular aluno'),
          ),
        ],
      ),
    ),
  );
}
