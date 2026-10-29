import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../domain/convert_policy.dart';
import '../../platform/portuguese_sort.dart';

Uri? brazilWhatsApp(String? phone) {
  if (phone == null || RegExp(r'[A-Za-z]').hasMatch(phone)) return null;
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 || digits.length == 13) {
    if (!digits.startsWith('55')) return null;
    digits = digits.substring(2);
  }
  if (!RegExp(r'^[1-9][1-9](?:[2-5]\d{7}|9\d{8})$').hasMatch(digits)) {
    return null;
  }
  return Uri.https('wa.me', '/55$digits');
}

String statusCode(ConvertRecord record, DateOnly today) =>
    switch (visitState(record, today)) {
      VisitState.urgent => 'red',
      VisitState.current => 'green',
      VisitState.attention => 'yellow',
    };
Future<Map<String, int>> convertNameRanks(
  List<ConvertRecord> rows, {
  Future<List<String>> Function(List<String>) sortNames = sortPortugueseNames,
}) async {
  final names = rows.map((row) => row.name).toSet().toList();
  final sorted = names.length < 2 ? names : await sortNames(names);
  if (sorted.length != names.length ||
      sorted.toSet().length != names.length ||
      !sorted.toSet().containsAll(names)) {
    throw StateError('Invalid locale ordering');
  }
  return {for (final entry in sorted.indexed) entry.$2: entry.$1};
}

List<ConvertRecord> visibleConverts(
  List<ConvertRecord> rows,
  List<Congregation> congregations,
  AccessScope scope,
  DateOnly today, {
  String name = '',
  String? congregationId,
  String? status,
  Map<String, int>? nameRanks,
}) {
  final congregationsById = {
    for (final congregation in congregations) congregation.id: congregation,
  };
  // Keep equal-name congregations as distinct groups in prepared locale order.
  final groupRanks = {
    for (final entry in congregations.indexed) entry.$2.id: entry.$1,
  };
  final indexed = rows.indexed.where((entry) {
    final row = entry.$2;
    return !isTerminal(row) &&
        scope.canAccess(row.congregationId) &&
        row.name.toLowerCase().contains(name.toLowerCase()) &&
        (congregationId == null || row.congregationId == congregationId) &&
        (status == null || statusCode(row, today) == status);
  }).toList();
  indexed.sort((a, b) {
    int severity(ConvertRecord row) => switch (visitState(row, today)) {
      VisitState.urgent => 0,
      VisitState.attention => 1,
      VisitState.current => 2,
    };
    var order = severity(a.$2).compareTo(severity(b.$2));
    if (order != 0) return order;
    final ca = congregationsById[a.$2.congregationId];
    final cb = congregationsById[b.$2.congregationId];
    order = ca == null
        ? (cb == null ? 0 : 1)
        : (cb == null ? -1 : groupRanks[ca.id]!.compareTo(groupRanks[cb.id]!));
    if (order != 0) return order;
    final rankA = nameRanks?[a.$2.name];
    final rankB = nameRanks?[b.$2.name];
    order = rankA != null && rankB != null
        ? rankA.compareTo(rankB)
        : a.$2.name.toLowerCase().compareTo(b.$2.name.toLowerCase());
    return order != 0 ? order : a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

enum ConvertAction { visit, start, stop, complete, deviate, delete }

String actionLabel(ConvertAction action) => switch (action) {
  ConvertAction.visit => 'Visita realizada/entramos em contato',
  ConvertAction.start => 'Iniciou discipulado',
  ConvertAction.stop => 'Interromper discipulado',
  ConvertAction.complete => 'Concluiu o discipulado',
  ConvertAction.deviate => 'Desviou-se',
  ConvertAction.delete => 'Excluir cadastro',
};
bool actionAllowed(
  ConvertAction action,
  ConvertRecord record,
  DateOnly today,
) => switch (action) {
  ConvertAction.visit => needsVisit(record, today),
  ConvertAction.start => canStartDiscipleship(record),
  ConvertAction.stop => canStopDiscipleship(record),
  ConvertAction.complete => canCompleteDiscipleship(record, today),
  ConvertAction.deviate => canMarkDeviated(record),
  ConvertAction.delete => record.deletedAt == null,
};

/// Retained failures keep their receipt identity until success or owner disposal.
class ConvertActions {
  ConvertActions(this.gateway) : _context = gateway.context;
  final Gateway gateway;
  final String _context;
  final Map<String, String> _operations = {};
  final Set<String> _pending = {};
  bool _disposed = false;
  Future<void> execute(
    ConvertAction action,
    ConvertRecord record, {
    String? classId,
  }) async {
    if (action == ConvertAction.start && classId == null) {
      throw const DataFailure('invalid');
    }
    gateway.ensureCurrent(_context);
    if (_disposed) throw const DataFailure('stale');
    final key = '${record.id}:${action.name}';
    if (!_pending.add(record.id)) throw const DataFailure('invalid');
    final operation = _operations.putIfAbsent(key, () => const Uuid().v4());
    try {
      final result = await gateway.command(
        action == ConvertAction.delete
            ? 'delete_convert'
            : 'transition_convert',
        operation,
        {
          'id': record.id,
          if (action != ConvertAction.delete) 'action': action.name,
          if (action == ConvertAction.start) 'class_id': classId,
        },
      );
      gateway.ensureCurrent(_context);
      if (_disposed) throw const DataFailure('stale');
      if (result.status != MutationStatus.applied) {
        throw DataFailure(result.errorCode ?? 'backend');
      }
      _operations.remove(key);
    } on DataFailure catch (error) {
      if (error.code == 'invalid' ||
          error.code == 'academic_invalid' ||
          error.code == 'permission') {
        _operations.remove(key);
      }
      rethrow;
    } finally {
      _pending.remove(record.id);
    }
  }

  void clear() {
    _disposed = true;
    _operations.clear();
    _pending.clear();
  }
}
