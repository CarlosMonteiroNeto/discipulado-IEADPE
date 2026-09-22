/// Attendance and progress handlers for the direct transport (internal mode).
///
/// Mirrors `functions/src/attendance`: the first saved attendance freezes the
/// eligible enrollment interval into the session `roster` subcollection, so a
/// later rename never rewrites historical labels and a late enrollment can
/// never silently join a session. Progress counts only finalized sessions whose
/// frozen roster contains the enrollment and whose date sits inside the
/// enrollment window, computed strictly client-side. Internal mode drops the
/// `rosterEnrollmentIds` denormalized index, the `internal/sessionIndex` and
/// every receipt; collection reads are plain `DirectStore.query` calls.
library;

import '../../domain/attendance.dart';
import '../../domain/common.dart';
import '../../domain/session.dart';
import '../../domain/validation.dart';
import '../direct_store.dart';
import '../error_mapper.dart';
import '../transport_support.dart';
import 'enrollments.dart' show maxEnrollmentRecords;

/// The attendance slice of the direct-transport dispatch table.
Map<String, DirectOperationHandler> attendanceHandlers() =>
    <String, DirectOperationHandler>{
      'saveAttendance': saveAttendanceHandler,
      'getSessionAttendance': getSessionAttendanceHandler,
      'getEnrollmentProgress': getEnrollmentProgressHandler,
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

int _requirePositiveRevision(Object? value) {
  if (value is! int || value < 1) {
    throw validationFailure('expectedRevision deve ser um inteiro positivo.');
  }
  return value;
}

String _requireCongregationId(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw validationFailure(
      'A chamada requer a congregação.',
      fieldErrors: <String, String>{
        'congregationId': 'congregaçãoId é obrigatória.',
      },
    );
  }
  return value.trim();
}

String _requireId(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw validationFailure(
      'Campo obrigatório ausente.',
      fieldErrors: <String, String>{field: 'Campo obrigatório ausente.'},
    );
  }
  return value.trim();
}

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

bool _requireBool(Object? value) {
  if (value is! bool) {
    throw validationFailure('Valor inválido.', fieldErrors: <String, String>{
      'finalize': 'Valor inválido.',
    });
  }
  return value;
}

Map<String, String> _requireMarks(Object? value) {
  final Object? attendance = value;
  if (attendance is! Map) {
    throw validationFailure(
      'Atributos de presença inválidos.',
      fieldErrors: <String, String>{
        'attendance': 'Atributos de presença inválidos.',
      },
    );
  }
  final Map<String, String> marks = <String, String>{};
  for (final MapEntry<Object?, Object?> entry in attendance.entries) {
    if (entry.key is! String || entry.value is! String) {
      throw validationFailure(
        'Atributos de presença inválidos.',
        fieldErrors: <String, String>{
          'attendance': 'Atributos de presença inválidos.',
        },
      );
    }
    marks[entry.key! as String] = entry.value! as String;
  }
  return marks;
}

/// Archived congregations deny attendance edits.
Future<void> _assertActiveCongregation(
  DirectTransaction tx,
  String congregationId,
) async {
  final JsonMap? congregation = await tx
      .read(StorePaths.congregation(congregationId));
  if (congregation == null) {
    throw notFoundFailure(kNotFoundMessage);
  }
  if (congregation['active'] != true) {
    throw conflictFailure('A congregação está inativa.');
  }
}

Future<JsonMap> _locateSession(
  DirectTransaction tx,
  String congregationId,
  String sessionId,
) async {
  final JsonMap? session = await tx.read(StorePaths.session(congregationId, sessionId));
  if (session == null || session['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  return session;
}

/// Completed and archived classes are read-only for attendance (S08).
Future<void> _assertMutableClass(
  DirectTransaction tx,
  String congregationId,
  String classId,
) async {
  final JsonMap? document = await tx.read(
    StorePaths.classGroup(congregationId, classId),
  );
  if (document == null || document['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  if (document['status'] != 'active') {
    throw conflictFailure('As turmas concluídas são somente leitura.');
  }
}

/// First save freezes every enrollment whose date interval includes the
/// session date; the name comes from the class roster snapshot captured at
/// enrollment time, falling back to the student document (S08).
Future<List<JsonMap>> _frozenRosterEntries(
  DirectStore store,
  String congregationId,
  String classId,
  String sessionId,
  String dateString,
  DateTime now,
  String uid,
) async {
  final List<JsonMap> enrollments = await store.query(
    StoreQuery(
      collection: StorePaths.enrollmentsCollection(congregationId),
      filters: <String, Object?>{'classId': classId},
    ),
  );
  final List<JsonMap> eligible = enrollments
      .where((JsonMap enrollment) => _isEligibleOnDate(enrollment, dateString))
      .toList()
    ..sort(
      (JsonMap a, JsonMap b) =>
          '${a['id']}'.compareTo('${b['id']}'),
    );
  if (eligible.length > maxEnrollmentRecords) {
    throw conflictFailure(
      'Uma sessão está limitada a $maxEnrollmentRecords alunos no quadro.',
    );
  }

  final List<JsonMap> entries = <JsonMap>[];
  for (final JsonMap enrollment in eligible) {
    final String enrollmentId = '${enrollment['id']}';
    final String studentId = _nonEmpty(enrollment['studentId']) ?? '';
    final JsonMap? classRosterEntry = await store.read(
      'congregations/$congregationId/classes/$classId/roster/$enrollmentId',
    );
    String? studentName = _nonEmpty(classRosterEntry?['studentName']);
    if (studentName == null) {
      final JsonMap? student = await store.read(
        StorePaths.student(congregationId, studentId),
      );
      studentName = _nonEmpty(student?['name']) ?? studentId;
    }
    entries.add(<String, Object?>{
      'id': enrollmentId,
      'enrollmentId': enrollmentId,
      'studentId': studentId,
      'studentName': studentName,
      'sessionId': sessionId,
      'classId': classId,
      'congregationId': congregationId,
      'revision': 1,
      'createdAt': isoNow(now),
      'updatedAt': isoNow(now),
      'updatedBy': uid,
    });
  }
  return entries;
}

Future<List<JsonMap>> _sessionRosterEntries(
  DirectStore store,
  String congregationId,
  String sessionId,
) => store.query(
  StoreQuery(
    collection: StorePaths.roster(congregationId, sessionId),
    orderBy: 'enrollmentId',
  ),
);

/// S08: only enrollments whose interval includes the date may be frozen.
bool _isEligibleOnDate(JsonMap enrollment, String dateString) {
  final String? startDate = _nonEmpty(enrollment['startDate']);
  if (startDate == null || dateString.compareTo(startDate) < 0) {
    return false;
  }
  final String? endDate = _nonEmpty(enrollment['endDate']);
  if (endDate != null && dateString.compareTo(endDate) > 0) {
    return false;
  }
  return true;
}

Future<JsonMap> saveAttendanceHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(
    payload['congregationId'],
  );
  final String sessionId = _requireId(payload['sessionId'], 'sessionId');
  final int expectedRevision = _requirePositiveRevision(
    payload['expectedRevision'],
  );
  final bool finalize = _requireBool(payload['finalize']);
  final Object? rawLessonFinished = payload['lessonFinished'];
  if (rawLessonFinished != null && rawLessonFinished is! bool) {
    throw validationFailure(
      'Valor inválido.',
      fieldErrors: <String, String>{'lessonFinished': 'Valor inválido.'},
    );
  }
  final bool? lessonFinished =
      rawLessonFinished is bool ? rawLessonFinished : null;
  final Map<String, String> marks = _requireMarks(payload['attendance']);
  final List<String> markKeys = marks.keys.toList()..sort();
  if (markKeys.length > maxEnrollmentRecords) {
    throw conflictFailure(
      'Uma sessão está limitada a $maxEnrollmentRecords alunos no quadro.',
    );
  }
  final Set<String> knownStatuses = AttendanceStatus.values
      .map((AttendanceStatus value) => value.wire)
      .toSet();

  final DirectStore store = context.store;
  final String sessionPath = StorePaths.session(congregationId, sessionId);
  final JsonMap? storedSession = await store.read(sessionPath);
  if (storedSession == null ||
      storedSession['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  if (storedSession['status'] == SessionStatus.canceled.wire) {
    throw conflictFailure('As reuniões canceladas não podem ser editadas.');
  }
  if (storedSession['status'] == SessionStatus.finalized.wire &&
      finalize != true) {
    throw conflictFailure(
      'Uma reunião finalizada só pode ser corrigida com finalização.',
    );
  }
  final String? classId = _nonEmpty(storedSession['classId']);
  if (classId == null) {
    throw conflictFailure('A turma da reunião está indisponível.');
  }
  final String? dateString = _nonEmpty(storedSession['date']);
  if (dateString == null) {
    throw conflictFailure('A data da reunião está indisponível.');
  }
  final DateTime nowIso = context.now;

  final List<JsonMap> frozenEntries;
  final bool requiresFreeze = storedSession['rosterFrozen'] != true;
  if (requiresFreeze) {
    frozenEntries = await _frozenRosterEntries(
      store,
      congregationId,
      classId,
      sessionId,
      dateString,
      nowIso,
      context.uid,
    );
  } else {
    frozenEntries = await _sessionRosterEntries(store, congregationId, sessionId);
  }

  final List<String> rosterIds = frozenEntries
      .map((JsonMap entry) => '${entry['enrollmentId']}')
      .toList()
    ..sort();
  bool sameMembership = rosterIds.length == markKeys.length;
  if (sameMembership) {
    for (int index = 0; index < rosterIds.length; index++) {
      if (rosterIds[index] != markKeys[index]) {
        sameMembership = false;
        break;
      }
    }
  }
  if (!sameMembership) {
    throw validationFailure(
      'A chamada deve conter exatamente o quadro de alunos congelado.',
      fieldErrors: <String, String>{
        'attendance': 'A chamada deve conter exatamente o quadro de alunos congelado.',
      },
    );
  }

  for (final String key in markKeys) {
    if (!knownStatuses.contains(marks[key])) {
      throw validationFailure(
        'Status de presença inválido.',
        fieldErrors: <String, String>{'attendance': 'Status de presença inválido.'},
      );
    }
  }

  if (finalize) {
    if (rosterIds.isEmpty) {
      throw conflictFailure('A finalização exige pelo menos um aluno no quadro.');
    }
    if (markKeys.any((String key) => marks[key] == AttendanceStatus.unmarked.wire)) {
      throw validationFailure(
        'Todos os alunos devem ser marcados antes da finalização.',
        fieldErrors: <String, String>{
          'attendance': 'Todos os alunos devem ser marcados antes da finalização.',
        },
      );
    }
    final String today = recifeToday(nowIso).toIso8601String();
    if (dateString.compareTo(today) > 0) {
      throw validationFailure(
        'Uma chamada não pode ser finalizada antes da data da aula.',
        fieldErrors: <String, String>{
          'date': 'Uma chamada não pode ser finalizada antes da data da aula.',
        },
      );
    }
  }

  return store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);
    final JsonMap session = await _locateSession(tx, congregationId, sessionId);
    if (session['status'] == SessionStatus.canceled.wire) {
      throw conflictFailure('As reuniões canceladas não podem ser editadas.');
    }
    if (session['status'] == SessionStatus.finalized.wire && finalize != true) {
      throw conflictFailure(
        'Uma reunião finalizada só pode ser corrigida com finalização.',
      );
    }
    await _assertMutableClass(tx, congregationId, classId);
    _assertRevision(session, expectedRevision);

    // All transaction reads must precede all writes (S09): resolve the
    // attendance documents before any mutation (roster freeze, marks)
    // so the web SDK does not abort with a read-after-write violation.
    final Map<String, (JsonMap?, Object?)> attendanceStates =
        <String, (JsonMap?, Object?)>{};
    for (final String key in markKeys) {
      final JsonMap? existing = await tx.read(
        '${StorePaths.attendance(congregationId, sessionId)}/$key',
      );
      attendanceStates[key] = (existing, existing?['createdAt']);
    }

    if (requiresFreeze) {
      for (final JsonMap entry in frozenEntries) {
        final String enrollmentId = '${entry['enrollmentId']}';
        await tx.write(
          '${StorePaths.roster(congregationId, sessionId)}/$enrollmentId',
          entry,
        );
      }
    }

    for (final String key in markKeys) {
      final JsonMap entry = frozenEntries.firstWhere(
        (JsonMap candidate) => '${candidate['enrollmentId']}' == key,
      );
      final String attendancePath =
          '${StorePaths.attendance(congregationId, sessionId)}/$key';
      final (JsonMap? existing, Object? priorCreatedAt) = attendanceStates[key]!;
      await tx.write(attendancePath, <String, Object?>{
        'id': key,
        'enrollmentId': key,
        'studentId': '${entry['studentId']}',
        'status': marks[key],
        'sessionId': sessionId,
        'classId': classId,
        'congregationId': congregationId,
        'revision': existing == null ? 1 : _revisionOf(existing) + 1,
        'createdAt': priorCreatedAt is String ? priorCreatedAt : isoNow(nowIso),
        'updatedAt': isoNow(nowIso),
        'updatedBy': context.uid,
      });
    }

    final String targetStatus =
        finalize || session['status'] == SessionStatus.finalized.wire
            ? SessionStatus.finalized.wire
            : SessionStatus.open.wire;
    final JsonMap next = _revised(
      session,
      changes: <String, Object?>{
        if (requiresFreeze) 'rosterFrozen': true,
        'lessonFinished': ?lessonFinished,
        'status': targetStatus,
      },
      now: nowIso,
      uid: context.uid,
    );
    await tx.write(sessionPath, next);
    return <String, Object?>{'id': sessionId, 'revision': _revisionOf(next)};
  });
}

Future<JsonMap> getSessionAttendanceHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(
    payload['congregationId'],
  );
  final String sessionId = _requireId(payload['sessionId'], 'sessionId');
  final DirectStore store = context.store;

  final JsonMap? session = await store.read(
    StorePaths.session(congregationId, sessionId),
  );
  if (session == null || session['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }

  final List<JsonMap> rosterEntries;
  if (session['rosterFrozen'] != true) {
    // A not-yet-saved session has no frozen roster prefix; surface the
    // currently eligible enrollments so the editor never looks empty (S08).
    final String? classId = _nonEmpty(session['classId']);
    final String? dateString = _nonEmpty(session['date']);
    if (classId == null || dateString == null) {
      throw conflictFailure('A turma ou data da reunião está indisponível.');
    }
    rosterEntries = await _frozenRosterEntries(
      store,
      congregationId,
      classId,
      sessionId,
      dateString,
      context.now,
      context.uid,
    );
  } else {
    rosterEntries = await _sessionRosterEntries(
      store,
      congregationId,
      sessionId,
    );
  }
  final List<JsonMap> attendanceEntries = await store.query(
    StoreQuery(
      collection: StorePaths.attendance(congregationId, sessionId),
      orderBy: 'enrollmentId',
    ),
  );
  final Map<String, String> statusById = <String, String>{
    for (final JsonMap entry in attendanceEntries)
      if (entry['enrollmentId'] is String && entry['status'] is String)
        entry['enrollmentId']! as String: entry['status']! as String,
  };

  final List<JsonMap> roster = rosterEntries
      .map(
        (JsonMap entry) => <String, Object?>{
          'enrollmentId': '${entry['enrollmentId']}',
          'studentId': '${entry['studentId'] ?? ''}',
          'studentName': '${entry['studentName'] ?? ''}',
          'status': statusById['${entry['enrollmentId']}'] ??
              AttendanceStatus.unmarked.wire,
        },
      )
      .toList(growable: false);
  return <String, Object?>{'session': session, 'roster': roster};
}

Future<JsonMap> getEnrollmentProgressHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(
    payload['congregationId'],
  );
  final String enrollmentId = _requireId(payload['enrollmentId'], 'enrollmentId');
  final DirectStore store = context.store;

  final JsonMap? enrollment = await store.read(
    StorePaths.enrollment(congregationId, enrollmentId),
  );
  if (enrollment == null || enrollment['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  final String? classId = _nonEmpty(enrollment['classId']);
  if (classId == null) {
    throw notFoundFailure('A matrícula está sem turma.');
  }
  final String? startDate = _nonEmpty(enrollment['startDate']);
  final String? endDate = _nonEmpty(enrollment['endDate']);

  final List<JsonMap> sessions = await store.query(
    StoreQuery(
      collection: StorePaths.sessionsCollection(congregationId),
      filters: <String, Object?>{'classId': classId},
    ),
  );

  int present = 0;
  int absent = 0;
  int excused = 0;
  for (final JsonMap session in sessions) {
    if (session['status'] != SessionStatus.finalized.wire) continue;
    final String? sessionDate = _nonEmpty(session['date']);
    if (sessionDate == null) continue;
    if (startDate != null && sessionDate.compareTo(startDate) < 0) continue;
    if (endDate != null && sessionDate.compareTo(endDate) > 0) continue;

    final List<JsonMap> members = await store.query(
      StoreQuery(
        collection: StorePaths.roster(congregationId, '${session['id']}'),
        filters: <String, Object?>{'enrollmentId': enrollmentId},
      ),
    );
    if (members.isEmpty) continue;

    final JsonMap? mark = await store.read(
      '${StorePaths.attendance(congregationId, '${session['id']}')}/$enrollmentId',
    );
    final String? markStatus = _nonEmpty(mark?['status']);
    if (markStatus == AttendanceStatus.present.wire) {
      present += 1;
    } else if (markStatus == AttendanceStatus.absent.wire) {
      absent += 1;
    } else if (markStatus == AttendanceStatus.excused.wire) {
      excused += 1;
    }
  }

  final int total = present + absent;
  final int? percentage =
      total > 0 ? (present / total * 100).round() : null;
  return <String, Object?>{
    'enrollmentId': enrollmentId,
    'classId': classId,
    'present': present,
    'absent': absent,
    'excused': excused,
    'percentage': percentage,
  };
}