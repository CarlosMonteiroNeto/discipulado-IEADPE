/// Congregation lifecycle handlers for the direct transport (internal mode).
///
/// Mirrors `functions/src/congregations` without the server-only guarantees:
/// normalized-name uniqueness is an advisory pre-transaction read (never a
/// reservation write) and no scope-reference counters are maintained.
library;

import '../../domain/common.dart';
import '../../domain/validation.dart';
import '../direct_store.dart';
import '../error_mapper.dart';
import '../transport_support.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// The congregation slice of the direct-transport dispatch table.
Map<String, DirectOperationHandler> congregationsHandlers() =>
    <String, DirectOperationHandler>{
      'saveCongregation': saveCongregationHandler,
      'setCongregationArchived': setCongregationArchivedHandler,
    };

int _revisionOf(JsonMap record) =>
    record['revision'] is int ? record['revision'] as int : 0;

void _assertRevision(JsonMap record, int expected) {
  if (_revisionOf(record) != expected) {
    throw conflictFailure(kConflictMessage);
  }
}

JsonMap _revised(
  JsonMap record, {
  required Map<String, Object?> changes,
  required DateTime now,
  required String uid,
}) =>
    <String, Object?>{
      ...record,
      ...changes,
      'revision': _revisionOf(record) + 1,
      'updatedAt': isoNow(now),
      'updatedBy': uid,
    };

int? _optionalPositiveRevision(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! int || value < 1) {
    throw validationFailure('expectedRevision deve ser um inteiro positivo.');
  }
  return value;
}

Future<JsonMap> saveCongregationHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String id = requirePayloadString(payload, 'id');
  final String name = requirePayloadString(payload, 'name');
  final String? nameError = validateDisplayName(name);
  if (nameError != null) {
    throw validationFailure(nameError, fieldErrors: <String, String>{
      'name': nameError,
    });
  }
  final int? expectedRevision = _optionalPositiveRevision(
    payload['expectedRevision'],
  );
  final bool isCreate = expectedRevision == null;
  if (isCreate && !_uuidPattern.hasMatch(id)) {
    throw validationFailure('id deve ser um UUID.', fieldErrors: <String, String>{
      'id': 'id deve ser um UUID.',
    });
  }

  final String trimmed = name.trim();
  final String normalized = normalizeName(name);
  final List<JsonMap> existing = await context.store.query(
    StoreQuery(
      collection: 'congregations',
      filters: <String, Object?>{'normalizedName': normalized},
    ),
  );
  for (final JsonMap row in existing) {
    if (row['id'] != id) {
      throw conflictFailure('Já existe uma congregação com este nome.');
    }
  }

  final String path = StorePaths.congregation(id);
  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    final JsonMap? stored = await tx.read(path);
    if (isCreate) {
      if (stored != null) {
        throw conflictFailure(kConflictMessage);
      }
      await tx.write(
        path,
        withRecordMeta(
          base: <String, Object?>{
            'id': id,
            'name': trimmed,
            'normalizedName': normalized,
            'active': true,
          },
          now: context.now,
          uid: context.uid,
          revision: 1,
        ),
      );
      return <String, Object?>{'id': id, 'revision': 1};
    }

    if (stored == null) {
      throw notFoundFailure(kNotFoundMessage);
    }
    if (stored['active'] != true) {
      throw conflictFailure(
        'Congregações arquivadas são somente leitura exceto restauração.',
      );
    }
    _assertRevision(stored, expectedRevision);
    await tx.write(
      path,
      _revised(
        stored,
        changes: <String, Object?>{
          'name': trimmed,
          'normalizedName': normalized,
        },
        now: context.now,
        uid: context.uid,
      ),
    );
    return <String, Object?>{'id': id, 'revision': _revisionOf(stored) + 1};
  });
}

Future<JsonMap> setCongregationArchivedHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String id = requirePayloadString(payload, 'id');
  final bool archived = requirePayloadBool(payload, 'archived');
  final int expectedRevision = requirePayloadInt(payload, 'expectedRevision');
  if (expectedRevision < 1) {
    throw validationFailure('expectedRevision deve ser um inteiro positivo.');
  }

  final String path = StorePaths.congregation(id);
  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    final JsonMap? stored = await tx.read(path);
    if (stored == null) {
      throw notFoundFailure(kNotFoundMessage);
    }
    final bool isArchived = stored['active'] != true;
    if (isArchived == archived) {
      return <String, Object?>{'id': id, 'revision': _revisionOf(stored)};
    }
    _assertRevision(stored, expectedRevision);
    await tx.write(
      path,
      _revised(
        stored,
        changes: <String, Object?>{'active': !archived},
        now: context.now,
        uid: context.uid,
      ),
    );
    return <String, Object?>{'id': id, 'revision': _revisionOf(stored) + 1};
  });
}