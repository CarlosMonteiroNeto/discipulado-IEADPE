/// Session lifecycle handlers for the direct transport (internal mode).
///
/// Mirrors `functions/src/sessions/service.ts`: an open session record until
/// attendance is saved or finalized, cancellation keeps the document and its
/// roster/marks as history. Internal mode drops the `sessionDates` lock, the
/// class `internal/sessionIndex` and every receipt; the same-class/same-date
/// check is an advisory plain read, so duplicate races remain possible.
library;

import '../../domain/common.dart';
import '../../domain/curriculum.dart';
import '../../domain/session.dart';
import '../direct_store.dart';
import '../error_mapper.dart';
import '../transport_support.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// The sessions slice of the direct-transport dispatch table.
Map<String, DirectOperationHandler> sessionsHandlers() =>
    <String, DirectOperationHandler>{
      'createSession': createSessionHandler,
      'cancelSession': cancelSessionHandler,
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
      'A reunião requer a congregação.',
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

/// Archived congregations are read-only except restoration, so session
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
    throw conflictFailure('As reuniões exigem uma turma ativa.');
  }
  return document;
}

void _assertWithinClassPeriod(CalendarDate date, JsonMap classDocument) {
  final String iso = date.toIso8601String();
  final String? classStart = _nonEmpty(classDocument['startDate']);
  if (classStart != null && iso.compareTo(classStart) < 0) {
    throw validationFailure(
      'A data deve estar dentro do período da turma.',
      fieldErrors: <String, String>{
        'date': 'A data deve estar dentro do período da turma.',
      },
    );
  }
  final String? classEnd = _nonEmpty(classDocument['endDate']);
  if (classEnd != null && iso.compareTo(classEnd) > 0) {
    throw validationFailure(
      'A data deve estar dentro do período da turma.',
      fieldErrors: <String, String>{
        'date': 'A data deve estar dentro do período da turma.',
      },
    );
  }
}

/// Plain store read of the class's sessions, mirroring the injected session
/// port of the reference. The same-class/same-date uniqueness check is
/// advisory in internal mode.
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

/// The class's past sessions that carry lesson fields, earliest date first.
/// Canceled sessions never participate in the sequence (S09-like).

Future<JsonMap> createSessionHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(payload['congregationId']);
  final String id = _requireId(payload['id'], 'id');
  final String classId = _requireId(payload['classId'], 'classId');
  final CalendarDate date = _parseDate(payload['date'], 'date');
  if (!_uuidPattern.hasMatch(id)) {
    throw validationFailure('id deve ser um UUID.', fieldErrors: <String, String>{
      'id': 'id deve ser um UUID.',
    });
  }
  final String dateString = date.toIso8601String();
  final String path = StorePaths.session(congregationId, id);

  final List<JsonMap> classSessions = await _sessionsOf(
    context.store,
    congregationId,
    classId,
  );
  final bool duplicate = classSessions.any(
    (JsonMap session) =>
        session['status'] != SessionStatus.canceled.wire &&
        session['date'] == dateString,
  );
  if (duplicate) {
    throw conflictFailure('Já existe uma reunião para esta turma e data.');
  }

  final List<JsonMap> sequenced = classSessions
      .where(
        (JsonMap session) =>
            session['status'] != SessionStatus.canceled.wire &&
            session['lessonIndex'] is int &&
            session['lessonPart'] is int,
      )
      .toList()
    ..sort(
      (JsonMap a, JsonMap b) =>
          '${a['date']}'.compareTo('${b['date']}'),
    );
  final NextLesson next = nextLesson(<NextLesson>[
    for (final JsonMap session in sequenced)
      NextLesson(
        lessonIndex: session['lessonIndex'] as int,
        lessonPart: session['lessonPart'] as int,
        lessonFinished: session['lessonFinished'] == true,
      ),
  ]);
  final String topic = lessonTopic(
    lessonIndex: next.lessonIndex,
    lessonPart: next.lessonPart,
  );

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);
    final JsonMap classDocument = await _locateClass(
      tx,
      congregationId,
      classId,
      requireActive: true,
    );
    _assertWithinClassPeriod(date, classDocument);
    final JsonMap? stored = await tx.read(path);
    if (stored != null) {
      throw conflictFailure(kConflictMessage);
    }
    final JsonMap document = withRecordMeta(
      base: <String, Object?>{
        'id': id,
        'congregationId': congregationId,
        'classId': classId,
        'date': dateString,
        'topic': topic,
        'status': SessionStatus.open.wire,
        'rosterFrozen': false,
        'lessonIndex': next.lessonIndex,
        'lessonPart': next.lessonPart,
        'lessonFinished': false,
      },
      now: context.now,
      uid: context.uid,
      revision: 1,
    );
    await tx.write(path, document);
    return <String, Object?>{'id': id, 'revision': 1};
  });
}

Future<JsonMap> cancelSessionHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(payload['congregationId']);
  final String id = _requireId(payload['id'], 'id');
  _requireId(payload['classId'], 'classId');
  final int expectedRevision = _requirePositiveRevision(
    payload['expectedRevision'],
  );
  final String path = StorePaths.session(congregationId, id);

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);
    final JsonMap? session = await tx.read(path);
    if (session == null || session['congregationId'] != congregationId) {
      throw notFoundFailure(kNotFoundMessage);
    }
    if (session['status'] == SessionStatus.canceled.wire) {
      return <String, Object?>{'id': id, 'revision': _revisionOf(session)};
    }
    final String? classId = _nonEmpty(session['classId']);
    if (classId == null) {
      throw conflictFailure('A turma da reunião está indisponível.');
    }
    await _locateClass(tx, congregationId, classId, requireActive: true);
    _assertRevision(session, expectedRevision);
    final JsonMap next = _revised(
      session,
      changes: <String, Object?>{'status': SessionStatus.canceled.wire},
      now: context.now,
      uid: context.uid,
    );
    await tx.write(path, next);
    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}