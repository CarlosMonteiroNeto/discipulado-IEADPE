/// Team directory view state: filters, pagination and refresh (S06, S09, S10).
library;

import 'package:flutter/foundation.dart';

import '../../domain/access.dart';
import '../../domain/contact.dart';
import '../../domain/ports.dart';
import '../../ui/async_content.dart';
import '../auth/auth_controller.dart';
import 'team_repository.dart';

class TeamController extends ChangeNotifier implements SessionScoped {
  TeamController({required this.repository, required this.profile}) {
    _query = TeamQuery(congregationId: profile.congregationId);
  }

  final TeamRepository repository;
  AccessProfile profile;

  late TeamQuery _query;
  AsyncViewState<List<DirectoryEntry>> _state =
      const AsyncViewState<List<DirectoryEntry>>.loading();
  final List<String?> _cursorStack = <String?>[];
  String? _nextCursor;
  int _generation = 0;
  bool _disposed = false;

  TeamQuery get query => _query;

  AsyncViewState<List<DirectoryEntry>> get state => _state;

  bool get hasPreviousPage => _cursorStack.isNotEmpty;

  bool get hasNextPage => _nextCursor != null;

  /// Whether the caller may edit contacts in the current filter scope. Staff
  /// only ever manage their own congregation; supervisors manage any scope.
  bool get canManageCurrentScope {
    if (profile.accessRole == AccessRole.supervisor) {
      return true;
    }
    final ContactScope scope = _query.scope ?? ContactScope.congregation;
    return scope == ContactScope.congregation &&
        _query.congregationId != null &&
        _query.congregationId == profile.congregationId;
  }

  /// Reloads the current page without changing filters.
  Future<void> refresh() => _load(cursor: null);

  /// Applies new filters and resets pagination (S09).
  Future<void> applyQuery(TeamQuery next) {
    _query = next.copyWith(clearCursor: true);
    _cursorStack.clear();
    _nextCursor = null;
    return _load(cursor: null);
  }

  Future<void> setSearch(String search) =>
      applyQuery(_query.copyWith(search: search));

  Future<void> setScopeFilter(ContactScope? scope) {
    RoleCode? role = _query.roleCode;
    if (role != null && scope != null && role.scope != scope) {
      role = null;
    }
    return applyQuery(
      _query.copyWith(
        scope: scope,
        clearScope: scope == null,
        roleCode: role,
        clearRole: role == null,
      ),
    );
  }

  Future<void> setRoleFilter(RoleCode? role) {
    if (role == null) {
      return applyQuery(_query.copyWith(clearRole: true));
    }
    return applyQuery(_query.copyWith(scope: role.scope, roleCode: role));
  }

  Future<void> setArchived(bool archived) {
    final String? scopeId = _query.congregationId ?? profile.congregationId;
    return applyQuery(
      _query.copyWith(archived: archived, congregationId: scopeId),
    );
  }

  Future<void> nextPage() {
    final String? cursor = _nextCursor;
    if (cursor == null) {
      return Future<void>.value();
    }
    _cursorStack.add(_query.cursor);
    return _load(cursor: cursor);
  }

  Future<void> previousPage() {
    if (_cursorStack.isEmpty) {
      return Future<void>.value();
    }
    return _load(cursor: _cursorStack.removeLast());
  }

  Future<void> _load({required String? cursor}) async {
    final int generation = ++_generation;
    final TeamQuery request = _query.copyWith(
      cursor: cursor,
      clearCursor: cursor == null,
    );
    _emit(const AsyncViewState<List<DirectoryEntry>>.loading());
    try {
      final PageResult page = await repository.listDirectory(request);
      if (_disposed || generation != _generation) {
        return;
      }
      _query = request;
      _nextCursor = page.nextCursor;
      final List<DirectoryEntry> entries = page.items
          .map(DirectoryEntry.fromJson)
          .toList(growable: false);
      _emit(
        entries.isEmpty
            ? (request.hasSearch
                  ? AsyncViewState<List<DirectoryEntry>>.emptySearch(
                      query: request.search.trim(),
                    )
                  : const AsyncViewState<List<DirectoryEntry>>.emptyData())
            : AsyncViewState<List<DirectoryEntry>>.data(entries),
      );
    } catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      _emit(
        AsyncViewState<List<DirectoryEntry>>.fromFailure(_failureOf(error)),
      );
    }
  }

  AppFailure _failureOf(Object error) => error is AppFailure
      ? error
      : const AppFailure(
          code: AppFailureCode.unknown,
          message: 'Não foi possível carregar a equipe.',
        );

  void _emit(AsyncViewState<List<DirectoryEntry>> next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void clearSessionData() {
    _generation++;
    _query = TeamQuery(congregationId: profile.congregationId);
    _cursorStack.clear();
    _nextCursor = null;
    _state = const AsyncViewState<List<DirectoryEntry>>.loading();
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
