/// Congregation lifecycle view state and actionable archive explanations (S06).
library;

import 'package:flutter/foundation.dart';

import '../../domain/access.dart';
import '../../domain/congregation.dart';
import '../../domain/ports.dart';
import '../../ui/async_content.dart';
import '../auth/auth_controller.dart';
import '../team/team_repository.dart';
import 'congregation_repository.dart';

class CongregationController extends ChangeNotifier implements SessionScoped {
  CongregationController({required this.repository, required this.profile});

  final CongregationRepository repository;
  AccessProfile profile;

  AsyncViewState<List<Congregation>> _active =
      const AsyncViewState<List<Congregation>>.loading();
  AsyncViewState<List<Congregation>> _archived =
      const AsyncViewState<List<Congregation>>.loading();
  bool _submitting = false;
  AppFailure? _lastFailure;
  String? _archiveExplanation;
  bool _disposed = false;

  AsyncViewState<List<Congregation>> get activeState => _active;

  AsyncViewState<List<Congregation>> get archivedState => _archived;

  bool get isSupervisor => profile.accessRole == AccessRole.supervisor;

  bool get submitting => _submitting;

  AppFailure? get lastFailure => _lastFailure;

  /// Actionable explanation for a blocked archive, or `null`.
  String? get archiveExplanation => _archiveExplanation;

  Future<void> refresh() async {
    await Future.wait(<Future<void>>[_loadActive(), _loadArchived()]);
  }

  Future<void> _loadActive() async {
    _active = await _load(active: true);
    _notify();
  }

  Future<void> _loadArchived() async {
    _archived = await _load(active: false);
    _notify();
  }

  Future<AsyncViewState<List<Congregation>>> _load({
    required bool active,
  }) async {
    try {
      final List<Congregation> list = await repository.listCongregations(
        active: active,
      );
      return list.isEmpty
          ? const AsyncViewState<List<Congregation>>.emptyData()
          : AsyncViewState<List<Congregation>>.data(list);
    } catch (error) {
      return AsyncViewState<List<Congregation>>.fromFailure(_failureOf(error));
    }
  }

  Future<void> create(String name) =>
      _mutate(() => repository.saveCongregation(name: name));

  Future<void> rename(Congregation congregation, String name) => _mutate(
    () => repository.saveCongregation(
      name: name,
      id: congregation.id,
      expectedRevision: congregation.revision,
    ),
  );

  Future<void> archive(Congregation congregation) => _mutate(
    () => repository.setCongregationArchived(
      id: congregation.id,
      archived: true,
      expectedRevision: congregation.revision,
    ),
    archive: true,
  );

  Future<void> restore(Congregation congregation) => _mutate(
    () => repository.setCongregationArchived(
      id: congregation.id,
      archived: false,
      expectedRevision: congregation.revision,
    ),
  );

  Future<void> _mutate(
    Future<TeamMutationResult> Function() action, {
    bool archive = false,
  }) async {
    _submitting = true;
    _lastFailure = null;
    _archiveExplanation = null;
    _notify();
    try {
      await action();
      _submitting = false;
      _notify();
      await refresh();
    } on AppFailure catch (failure) {
      _submitting = false;
      _lastFailure = failure;
      if (archive && failure.code == AppFailureCode.conflict) {
        _archiveExplanation =
            'Não foi possível arquivar esta congregação porque ainda existem '
            'usuários ativos, alunos, contatos ou turmas vinculados. Resolva '
            'esses vínculos e tente novamente.';
      }
      _notify();
    }
  }

  AppFailure _failureOf(Object error) => error is AppFailure
      ? error
      : const AppFailure(
          code: AppFailureCode.unknown,
          message: 'Não foi possível carregar as congregações.',
        );

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void clearSessionData() {
    _active = const AsyncViewState<List<Congregation>>.loading();
    _archived = const AsyncViewState<List<Congregation>>.loading();
    _submitting = false;
    _lastFailure = null;
    _archiveExplanation = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
