/// Class lifecycle handlers for the direct transport (internal mode).
///
/// Mirrors `functions/src/classes/service.ts`: stable-ID class records whose
/// name and eligible teacher may change while active, dates freeze once any
/// enrollment or session exists (checked through a plain sessions read), and
/// status moves active -> completed -> archived with reactivation allowed from
/// archived only. The congregation `activeClasses` and contact
/// `teacherClassRefs` reference counters are dropped.
library;

import '../../domain/class_group.dart';
import '../../domain/common.dart';
import '../../domain/validation.dart';
import '../direct_store.dart';
import '../error_mapper.dart';
import '../transport_support.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// The classes slice of the direct-transport dispatch table.
Map<String, DirectOperationHandler> classesHandlers() =>
    <String, DirectOperationHandler>{
      'saveClass': saveClassHandler,
      'setClassStatus': setClassStatusHandler,
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

int _referenceCount(JsonMap document, String field) {
  final Object? value = document[field];
  return value is int ? value : 0;
}

int? _optionalPositiveRevision(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! int || value < 1) {
    throw validationFailure('expectedRevision deve ser um inteiro positivo.');
  }
  return value;
}

int _requirePositiveRevision(Object? value) {
  if (value is! int || value < 1) {
    throw validationFailure('expectedRevision deve ser um inteiro positivo.');
  }
  return value;
}

String _requireCongregationId(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw validationFailure(
      'A turma requer a congregação.',
      fieldErrors: <String, String>{'congregationId': 'congregaçãoId é obrigatória.'},
    );
  }
  return value.trim();
}

ClassStatus _parseStatus(Object? raw) {
  final ClassStatus status;
  try {
    status = ClassStatus.fromWire(raw is String ? raw : '');
  } on DataFormatException {
    throw validationFailure('Situação inválida.', fieldErrors: <String, String>{
      'status': 'Situação inválida.',
    });
  }
  return status;
}

CalendarDate _parseDate(Object? raw, String field) {
  if (raw is! String || raw.trim().isEmpty) {
    throw validationFailure(
      'Data inválida.',
      fieldErrors: <String, String>{field: 'Data inválida.'},
    );
  }
  try {
    return CalendarDate.parse(raw);
  } on FormatException {
    throw validationFailure(
      'Data inválida.',
      fieldErrors: <String, String>{field: 'Data inválida.'},
    );
  }
}

CalendarDate? _optionalDate(Object? raw, String field) {
  if (raw == null) {
    return null;
  }
  if (raw is String && raw.trim().isEmpty) {
    return null;
  }
  return _parseDate(raw, field);
}

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Archived congregations are read-only except restoration, so class
/// mutations refuse work inside an inactive or unknown congregation.
Future<void> _assertActiveCongregation(
  DirectTransaction tx,
  String congregationId,
) async {
  final JsonMap? congregation = await tx.read(StorePaths.congregation(congregationId));
  if (congregation == null) {
    throw notFoundFailure(kNotFoundMessage);
  }
  if (congregation['active'] != true) {
    throw conflictFailure('A congregação está inativa.');
  }
}

Future<({JsonMap document, String path})> _locateClass(
  DirectTransaction tx,
  String congregationId,
  String classId,
) async {
  final String path = StorePaths.classGroup(congregationId, classId);
  final JsonMap? document = await tx.read(path);
  if (document == null || document['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  return (document: document, path: path);
}

/// The assigned teacher must be an active local contact holding the teacher
/// role (S05). Any other contact state is rejected before the write.
Future<void> _assertEligibleTeacher(
  DirectTransaction tx,
  String congregationId,
  String contactId,
) async {
  final JsonMap? contact = await tx.read(
    StorePaths.contact(congregationId, contactId),
  );
  if (contact == null || contact['congregationId'] != congregationId) {
    throw conflictFailure('O professor deve ser um contato local.');
  }
  if (contact['archived'] == true) {
    throw conflictFailure('O contato do professor está arquivado.');
  }
  if (contact['roleCode'] != 'teacher') {
    throw conflictFailure('O contato designado não ocupa o papel de professor.');
  }
}

/// Plain store read of the class's sessions, mirroring the injected
/// `ClassSessionReader` port of the reference. Sessions belong to the session
/// feature, so this read runs outside the failing transaction.
Future<List<JsonMap>> _sessionsOf(
  DirectStore store,
  String congregationId,
  String classId,
) => store.query(
  StoreQuery(
    collection: StorePaths.sessionsCollection(congregationId),
    filters: <String, Object?>{'classId': classId},
  ),
);

Future<JsonMap> saveClassHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(payload['congregationId']);
  final String id = requirePayloadString(payload, 'id');
  final String name = requirePayloadString(payload, 'name');
  final String? nameError = validateDisplayName(name);
  if (nameError != null) {
    throw validationFailure(nameError, fieldErrors: <String, String>{
      'name': nameError,
    });
  }
  final CalendarDate startDate = _parseDate(payload['startDate'], 'startDate');
  final CalendarDate? endDate = _optionalDate(payload['endDate'], 'endDate');
  if (endDate != null && endDate.compareTo(startDate) < 0) {
    throw validationFailure(
      'A data final deve ser igual ou posterior à data inicial.',
      fieldErrors: <String, String>{
        'endDate': 'A data final deve ser igual ou posterior à data inicial.',
      },
    );
  }
  final String? teacherContactId = _nonEmpty(payload['teacherContactId']);
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
  final String startDateString = startDate.toIso8601String();
  final String? endDateString = endDate?.toIso8601String();
  final String path = StorePaths.classGroup(congregationId, id);
  final List<JsonMap> classSessions = await _sessionsOf(
    context.store,
    congregationId,
    id,
  );

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);
    if (teacherContactId != null) {
      await _assertEligibleTeacher(tx, congregationId, teacherContactId);
    }
    final JsonMap? stored = await tx.read(path);
    if (isCreate) {
      if (stored != null) {
        throw conflictFailure(kConflictMessage);
      }
      final JsonMap document = withRecordMeta(
        base: <String, Object?>{
          'id': id,
          'congregationId': congregationId,
          'name': trimmed,
          'normalizedName': normalized,
          'teacherContactId': teacherContactId,
          'startDate': startDateString,
          'endDate': endDateString,
          'status': ClassStatus.active.wire,
          'enrollmentCount': 0,
          'activeEnrollmentCount': 0,
        },
        now: context.now,
        uid: context.uid,
        revision: 1,
      );
      await tx.write(path, document);
      return <String, Object?>{'id': id, 'revision': 1};
    }

    final ({JsonMap document, String path}) located = await _locateClass(
      tx,
      congregationId,
      id,
    );
    final JsonMap storedDoc = located.document;
    if (storedDoc['status'] != ClassStatus.active.wire) {
      throw conflictFailure('Turmas concluídas e arquivadas são somente leitura.');
    }
    final int enrollmentCount = _referenceCount(storedDoc, 'enrollmentCount');
    final bool datesFrozen = enrollmentCount > 0 || classSessions.isNotEmpty;
    final String storedStart = storedDoc['startDate'] is String
        ? storedDoc['startDate']! as String
        : '';
    final String? storedEnd = _nonEmpty(storedDoc['endDate']);
    if (datesFrozen &&
        (startDateString != storedStart || endDateString != storedEnd)) {
      throw conflictFailure(
        'As datas da turma não podem mudar depois de existirem matrículas ou reuniões.',
      );
    }
    _assertRevision(storedDoc, expectedRevision);
    final JsonMap next = _revised(
      storedDoc,
      changes: <String, Object?>{
        'name': trimmed,
        'normalizedName': normalized,
        'teacherContactId': teacherContactId,
        'startDate': startDateString,
        'endDate': endDateString,
      },
      now: context.now,
      uid: context.uid,
    );
    await tx.write(located.path, next);
    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}

Future<JsonMap> setClassStatusHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(payload['congregationId']);
  final String id = requirePayloadString(payload, 'id');
  final ClassStatus targetStatus = _parseStatus(payload['status']);
  final int expectedRevision = _requirePositiveRevision(
    payload['expectedRevision'],
  );
  final List<JsonMap> classSessions = await _sessionsOf(
    context.store,
    congregationId,
    id,
  );

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);
    final ({JsonMap document, String path}) located = await _locateClass(
      tx,
      congregationId,
      id,
    );
    final JsonMap stored = located.document;
    final Object? rawStatus = stored['status'];
    final ClassStatus currentStatus;
    try {
      currentStatus = ClassStatus.fromWire(rawStatus is String ? rawStatus : '');
    } on DataFormatException {
      throw notFoundFailure(kNotFoundMessage);
    }
    if (currentStatus == targetStatus) {
      return <String, Object?>{'id': id, 'revision': _revisionOf(stored)};
    }

    final String? teacherContactId = _nonEmpty(stored['teacherContactId']);
    final int enrollmentCount = _referenceCount(stored, 'enrollmentCount');
    final int activeEnrollmentCount = _referenceCount(
      stored,
      'activeEnrollmentCount',
    );

    if (targetStatus == ClassStatus.completed) {
      if (currentStatus != ClassStatus.active) {
        throw conflictFailure('Turmas concluídas e arquivadas não podem ser reabertas.');
      }
      if (activeEnrollmentCount > 0) {
        throw conflictFailure(
          'A conclusão da turma exige que todas as matrículas sejam encerradas.',
        );
      }
      if (classSessions.any((JsonMap session) => session['status'] == 'open')) {
        throw conflictFailure(
          'A conclusão da turma exige que todas as reuniões estejam finalizadas ou canceladas.',
        );
      }
    } else if (targetStatus == ClassStatus.archived) {
      if (currentStatus == ClassStatus.active) {
        if (enrollmentCount > 0 || classSessions.isNotEmpty) {
          throw conflictFailure(
            'Uma turma ativa só pode ser arquivada sem matrículas ou reuniões.',
          );
        }
      } else if (currentStatus != ClassStatus.completed) {
        throw conflictFailure('Turmas arquivadas não podem ser arquivadas novamente.');
      }
    } else {
      // targetStatus == active: only archived classes may reactivate.
      if (currentStatus != ClassStatus.archived) {
        throw conflictFailure('Turmas concluídas e arquivadas não podem ser reabertas.');
      }
      if (teacherContactId != null) {
        await _assertEligibleTeacher(tx, congregationId, teacherContactId);
      }
    }

    _assertRevision(stored, expectedRevision);
    final JsonMap next = _revised(
      stored,
      changes: <String, Object?>{'status': targetStatus.wire},
      now: context.now,
      uid: context.uid,
    );
    await tx.write(located.path, next);
    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}