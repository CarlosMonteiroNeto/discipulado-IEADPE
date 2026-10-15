import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../domain/convert_policy.dart';

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

String _alphabetical(String text) {
  var result = text.toLowerCase();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'ê': 'e',
    'è': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ò': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  replacements.forEach((key, value) => result = result.replaceAll(key, value));
  return result;
}

int compareCongregations(Congregation a, Congregation b) {
  final sedeA = a.name.toLowerCase().contains('sede'),
      sedeB = b.name.toLowerCase().contains('sede');
  if (sedeA != sedeB) return sedeA ? -1 : 1;
  return _alphabetical(a.name).compareTo(_alphabetical(b.name));
}

String statusCode(ConvertRecord record, DateOnly today) =>
    switch (visitState(record, today)) {
      VisitState.urgent => 'red',
      VisitState.current => 'green',
      VisitState.attention => 'yellow',
    };
List<ConvertRecord> visibleConverts(
  List<ConvertRecord> rows,
  List<Congregation> congregations,
  AccessScope scope,
  DateOnly today, {
  String name = '',
  String? congregationId,
  String? status,
}) {
  final congregationsById = {
    for (final congregation in congregations) congregation.id: congregation,
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
    final ca = congregationsById[a.$2.congregationId],
        cb = congregationsById[b.$2.congregationId];
    var order = ca == null
        ? (cb == null ? 0 : 1)
        : (cb == null ? -1 : compareCongregations(ca, cb));
    if (order != 0) return order;
    final da = a.$2.createdAt, db = b.$2.createdAt;
    if (da != null && db != null) {
      order = db.compareTo(da);
    } else if (da != db) {
      order = da == null ? 1 : -1;
    }
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
  Future<void> execute(ConvertAction action, ConvertRecord record) async {
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
        },
      );
      gateway.ensureCurrent(_context);
      if (_disposed) throw const DataFailure('stale');
      if (result.status != MutationStatus.applied) {
        throw DataFailure(result.errorCode ?? 'backend');
      }
      _operations.remove(key);
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
