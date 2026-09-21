/// Enrollment lifecycle handlers for the direct transport (internal mode).
///
/// Mirrors `functions/src/enrollments/service.ts`: one student may hold a
/// single active enrollment (held by the internal `activeEnrollmentRefs`
/// uniqueness document), dates must fall inside the class period, and closing
/// (completed/withdrawn) makes a record immutable. Internal mode adds the
/// class roster subcollection entry (frozen student name for later attendance)
/// and the student `classId` current-class backfill that powers the plain
/// `listClassStudents` query. The capacity check stays best-effort: it reads
/// the class `enrollmentCount` inside the same transaction but races remain
/// possible.
library;

import '../../domain/common.dart';
import '../../domain/enrollment.dart';
import '../direct_store.dart';
import '../error_mapper.dart';
import '../transport_support.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// The S08 class-size limit, enforced as a best-effort length check.
const int maxEnrollmentRecords = 100;

/// The enrollments slice of the direct-transport dispatch table.
Map<String, DirectOperationHandler> enrollmentsHandlers() =>
    <String, DirectOperationHandler>{
      'enrollStudent': enrollStudentHandler,
      'closeEnrollment': closeEnrollmentHandler,
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
      'A matrícula requer a congregação.',
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

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Archived congregations are read-only except restoration, so enrollment
/// mutations refuse work inside an inactive or unknown congregation.
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

Future<({JsonMap document, String path})> _locateEnrollment(
  DirectTransaction tx,
  String congregationId,
  String enrollmentId,
) async {
  final String path = StorePaths.enrollment(congregationId, enrollmentId);
  final JsonMap? document = await tx.read(path);
  if (document == null || document['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  return (document: document, path: path);
}

Future<JsonMap> _locateClass(
  DirectTransaction tx,
  String congregationId,
  String classId, {
  required bool requireActive,
}) async {
  final JsonMap? document = await tx.read(
    StorePaths.classGroup(congregationId, classId),
  );
  if (document == null || document['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  if (requireActive && document['status'] != 'active') {
    throw conflictFailure('As matrículas exigem uma turma ativa.');
  }
  return document;
}

Future<JsonMap> _locateStudent(
  DirectTransaction tx,
  String congregationId,
  String studentId,
) async {
  final JsonMap? document = await tx.read(
    StorePaths.student(congregationId, studentId),
  );
  if (document == null || document['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  return document;
}

/// A date must fall between the class start and end (inclusive), pt-BR as the
/// reference messages the S07 rule.
void _assertWithinClassPeriod(
  CalendarDate date,
  String field,
  JsonMap classDocument,
) {
  final String? classStart = _nonEmpty(classDocument['startDate']);
  if (classStart != null && date.toIso8601String().compareTo(classStart) < 0) {
    throw validationFailure(
      'A data deve estar dentro do período da turma.',
      fieldErrors: <String, String>{
        field: 'A data deve estar dentro do período da turma.',
      },
    );
  }
  final String? classEnd = _nonEmpty(classDocument['endDate']);
  if (classEnd != null && date.toIso8601String().compareTo(classEnd) > 0) {
    throw validationFailure(
      'A data deve estar dentro do período da turma.',
      fieldErrors: <String, String>{
        field: 'A data deve estar dentro do período da turma.',
      },
    );
  }
}

String _activeEnrollmentReferencePath(String congregationId, String studentId) =>
    'congregations/$congregationId/activeEnrollmentRefs/$studentId';

String _classRosterPath(
  String congregationId,
  String classId,
  String enrollmentId,
) =>
    'congregations/$congregationId/classes/$classId/roster/$enrollmentId';

Future<JsonMap> enrollStudentHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(payload['congregationId']);
  final String id = _requireId(payload['id'], 'id');
  final String classId = _requireId(payload['classId'], 'classId');
  final String studentId = _requireId(payload['studentId'], 'studentId');
  final CalendarDate startDate = _parseDate(payload['startDate'], 'startDate');
  final int? expectedRevision = _optionalPositiveRevision(
    payload['expectedRevision'],
  );
  final bool isCreate = expectedRevision == null;
  if (isCreate && !_uuidPattern.hasMatch(id)) {
    throw validationFailure('id deve ser um UUID.', fieldErrors: <String, String>{
      'id': 'id deve ser um UUID.',
    });
  }
  final String startDateString = startDate.toIso8601String();
  final String enrollmentPath = StorePaths.enrollment(congregationId, id);

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);

    if (isCreate) {
      final JsonMap? stored = await tx.read(enrollmentPath);
      if (stored != null) {
        throw conflictFailure(kConflictMessage);
      }
      final JsonMap classDocument = await _locateClass(
        tx,
        congregationId,
        classId,
        requireActive: true,
      );
      _assertWithinClassPeriod(startDate, 'startDate', classDocument);
      final JsonMap student = await _locateStudent(
        tx,
        congregationId,
        studentId,
      );
      if (student['archived'] == true) {
        throw conflictFailure('Alunos arquivados não podem ser matriculados.');
      }
      final String referencePath = _activeEnrollmentReferencePath(
        congregationId,
        studentId,
      );
      final JsonMap? reference = await tx.read(referencePath);
      if (reference != null) {
        throw conflictFailure('O aluno já possui uma matrícula ativa.');
      }
      final int enrollmentCount = _referenceCount(classDocument, 'enrollmentCount');
      if (enrollmentCount >= maxEnrollmentRecords) {
        throw conflictFailure(
          'Uma turma está limitada a $maxEnrollmentRecords registros de matrícula.',
        );
      }

      final JsonMap enrollmentDocument = withRecordMeta(
        base: <String, Object?>{
          'id': id,
          'congregationId': congregationId,
          'classId': classId,
          'studentId': studentId,
          'startDate': startDateString,
          'endDate': null,
          'status': EnrollmentStatus.active.wire,
        },
        now: context.now,
        uid: context.uid,
        revision: 1,
      );
      await tx.write(enrollmentPath, enrollmentDocument);

      final JsonMap referenceDocument = withRecordMeta(
        base: <String, Object?>{
          'studentId': studentId,
          'congregationId': congregationId,
          'enrollmentId': id,
          'classId': classId,
        },
        now: context.now,
        uid: context.uid,
        revision: 1,
      );
      await tx.write(referencePath, referenceDocument);

      final String studentName = student['name'] is String
          ? student['name']! as String
          : studentId;
      final JsonMap rosterEntry = withRecordMeta(
        base: <String, Object?>{
          'id': id,
          'enrollmentId': id,
          'studentId': studentId,
          'studentName': studentName,
          'classId': classId,
          'congregationId': congregationId,
        },
        now: context.now,
        uid: context.uid,
        revision: 1,
      );
      await tx.write(_classRosterPath(congregationId, classId, id), rosterEntry);

      await tx.write(
        StorePaths.classGroup(congregationId, classId),
        <String, Object?>{
          ...classDocument,
          'enrollmentCount': enrollmentCount + 1,
          'activeEnrollmentCount':
              _referenceCount(classDocument, 'activeEnrollmentCount') + 1,
        },
      );

      final JsonMap? currentStudent = await tx.read(
        StorePaths.student(congregationId, studentId),
      );
      await tx.write(
        StorePaths.student(congregationId, studentId),
        <String, Object?>{...?currentStudent, 'classId': classId},
      );

      return <String, Object?>{'id': id, 'revision': 1};
    }

    final ({JsonMap document, String path}) located = await _locateEnrollment(
      tx,
      congregationId,
      id,
    );
    final JsonMap stored = located.document;
    if (stored['status'] != EnrollmentStatus.active.wire) {
      throw conflictFailure('Uma matrícula encerrada é imutável.');
    }
    if (stored['studentId'] != studentId) {
      throw validationFailure(
        'Uma matrícula não pode mudar de aluno.',
        fieldErrors: <String, String>{'studentId': 'Uma matrícula não pode mudar de aluno.'},
      );
    }
    if (stored['classId'] != classId) {
      throw validationFailure(
        'Uma matrícula não pode mudar de turma.',
        fieldErrors: <String, String>{'classId': 'Uma matrícula não pode mudar de turma.'},
      );
    }
    final JsonMap classDocument = await _locateClass(
      tx,
      congregationId,
      classId,
      requireActive: true,
    );
    _assertWithinClassPeriod(startDate, 'startDate', classDocument);
    _assertRevision(stored, expectedRevision);
    final JsonMap next = _revised(
      stored,
      changes: <String, Object?>{'startDate': startDateString},
      now: context.now,
      uid: context.uid,
    );
    await tx.write(located.path, next);
    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}

Future<JsonMap> closeEnrollmentHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(payload['congregationId']);
  final String id = _requireId(payload['id'], 'id');
  final String classId = _requireId(payload['classId'], 'classId');
  final int expectedRevision = _requirePositiveRevision(
    payload['expectedRevision'],
  );
  final CalendarDate endDate = _parseDate(payload['endDate'], 'endDate');
  final EnrollmentStatus targetStatus;
  try {
    targetStatus = EnrollmentStatus.fromWire(payload['status'] is String
        ? payload['status']! as String
        : '');
  } on DataFormatException {
    throw validationFailure('Situação inválida.', fieldErrors: <String, String>{
      'status': 'Situação inválida.',
    });
  }
  if (targetStatus == EnrollmentStatus.active) {
    throw validationFailure(
      'Para encerrar, use concluída ou desistência.',
      fieldErrors: <String, String>{
        'status': 'Para encerrar, use concluída ou desistência.',
      },
    );
  }
  final String endDateString = endDate.toIso8601String();

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);
    final ({JsonMap document, String path}) located = await _locateEnrollment(
      tx,
      congregationId,
      id,
    );
    final JsonMap stored = located.document;
    if (stored['status'] != EnrollmentStatus.active.wire) {
      throw conflictFailure('Uma matrícula encerrada é imutável.');
    }
    if (stored['classId'] != classId) {
      throw validationFailure(
        'A matrícula não pertence à turma informada.',
        fieldErrors: <String, String>{
          'classId': 'A matrícula não pertence à turma informada.',
        },
      );
    }
    CalendarDate? storedStart;
    final String? rawStart = _nonEmpty(stored['startDate']);
    if (rawStart != null) {
      try {
        storedStart = CalendarDate.parse(rawStart);
      } on FormatException {
        storedStart = null;
      }
    }
    if (storedStart != null && endDate.compareTo(storedStart) < 0) {
      throw validationFailure(
        'A data final deve ser igual ou posterior à data inicial.',
        fieldErrors: <String, String>{
          'endDate': 'A data final deve ser igual ou posterior à data inicial.',
        },
      );
    }
    final JsonMap classDocument = await _locateClass(
      tx,
      congregationId,
      classId,
      requireActive: false,
    );
    _assertWithinClassPeriod(endDate, 'endDate', classDocument);
    _assertRevision(stored, expectedRevision);

    final JsonMap next = _revised(
      stored,
      changes: <String, Object?>{'status': targetStatus.wire, 'endDate': endDateString},
      now: context.now,
      uid: context.uid,
    );
    await tx.write(located.path, next);

    final String storedStudentId = stored['studentId'] is String
        ? stored['studentId']! as String
        : '';
    if (storedStudentId.isNotEmpty) {
      final String referencePath = _activeEnrollmentReferencePath(
        congregationId,
        storedStudentId,
      );
      final JsonMap? reference = await tx.read(referencePath);
      if (reference != null && reference['enrollmentId'] == id) {
        await tx.delete(referencePath);
      }
      // The plain students-by-class query resolves membership through the
      // optional student.classId backfill, so closing the active enrollment
      // must clear it; otherwise completed/withdrawn students keep appearing in
      // the class list.
      final String studentPath = StorePaths.student(
        congregationId,
        storedStudentId,
      );
      final JsonMap? student = await tx.read(studentPath);
      if (student != null && student['classId'] == classId) {
        final JsonMap cleared = <String, Object?>{...student}..remove('classId');
        await tx.write(studentPath, cleared);
      }
    }

    await tx.write(
      StorePaths.classGroup(congregationId, classId),
      <String, Object?>{
        ...classDocument,
        'activeEnrollmentCount': _referenceCount(
          classDocument,
          'activeEnrollmentCount',
        ) > 0
            ? _referenceCount(classDocument, 'activeEnrollmentCount') - 1
            : 0,
      },
    );

    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}