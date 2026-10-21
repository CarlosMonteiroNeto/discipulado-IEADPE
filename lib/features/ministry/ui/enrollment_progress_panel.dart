import 'package:flutter/material.dart';

import '../../../data/supabase_gateway.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';

/// Reusable persisted progress for exactly one selected enrollment.
///
/// The panel owns one fresh read of `ministry_get_enrollment_progress` per
/// selection or explicit refresh. It never derives or increments counters
/// locally, so finalized/canceled session changes are visible only after the
/// server read.
class EnrollmentProgressPanel extends StatefulWidget {
  const EnrollmentProgressPanel({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.enrollmentId,
  });

  final MinistryRepository repository;
  final String congregationId;
  final String enrollmentId;

  @override
  State<EnrollmentProgressPanel> createState() =>
      _EnrollmentProgressPanelState();
}

class _EnrollmentProgressPanelState extends State<EnrollmentProgressPanel> {
  EnrollmentProgress? _progress;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EnrollmentProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId ||
        oldWidget.enrollmentId != widget.enrollmentId) {
      _progress = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final congregationId = widget.congregationId;
    final enrollmentId = widget.enrollmentId;
    setState(() {
      _loading = true;
      _error = null;
      _progress = null;
    });
    try {
      final progress = await widget.repository.getEnrollmentProgress(
        congregationId: congregationId,
        enrollmentId: enrollmentId,
      );
      if (!mounted ||
          generation != _generation ||
          congregationId != widget.congregationId ||
          enrollmentId != widget.enrollmentId) {
        return;
      }
      setState(() {
        _progress = progress;
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          congregationId != widget.congregationId ||
          enrollmentId != widget.enrollmentId) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  String _message(Object error) {
    if (error is DataFailure) {
      return switch (error.code) {
        'permission' || 'forbidden' =>
          'Seu acesso mudou. Volte e atualize a sessão para ver o progresso.',
        'stale' =>
          'Sua sessão ou congregação mudou. Atualize a página para continuar.',
        'invalid_response' => 'O servidor retornou dados inconsistentes. Atualize e tente novamente.',
        _ => 'Não foi possível carregar o progresso da matrícula. Tente novamente.',
      };
    }
    return 'Não foi possível carregar o progresso da matrícula. Tente novamente.';
  }

  Widget _progressBody(EnrollmentProgress progress) {
    final hasEvaluatedSessions = progress.denominator > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aulas avaliadas: ${progress.denominator}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: UnifiedSpace.x2),
        Wrap(
          spacing: UnifiedSpace.x3,
          runSpacing: UnifiedSpace.x1,
          children: [
            Text('Presenças: ${progress.present}'),
            Text('Ausências: ${progress.absent}'),
            Text('Justificadas: ${progress.excused}'),
          ],
        ),
        const SizedBox(height: UnifiedSpace.x2),
        Text(
          hasEvaluatedSessions
              ? 'Aproveitamento: ${progress.roundedPercentage}%'
              : 'Sem aulas avaliadas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UnifiedSpace.x1),
        Text(
          'Somente aulas finalizadas e não canceladas entram no cálculo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Base44Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Progresso da matrícula',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: UnifiedSpace.x2),
          if (_loading) ...[
            const LinearProgressIndicator(
              semanticsLabel: 'Carregando progresso da matrícula',
            ),
            const SizedBox(height: UnifiedSpace.x2),
            const Text('Carregando progresso da matrícula…'),
          ],
          if (_error != null && !_loading) ...[
            Semantics(liveRegion: true, child: Text(_error!)),
            const SizedBox(height: UnifiedSpace.x2),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('retry-enrollment-progress'),
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ),
          ],
          if (progress != null)
            Semantics(liveRegion: true, child: _progressBody(progress)),
          const SizedBox(height: UnifiedSpace.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('refresh-enrollment-progress'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar progresso'),
            ),
          ),
        ],
      ),
    );
  }
}
