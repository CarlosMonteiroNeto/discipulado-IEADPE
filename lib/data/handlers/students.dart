/// Student persistence handlers for the direct transport (internal mode).
///
/// Mirrors `functions/src/students/service.ts`: private congregation-scoped
/// records keyed by stable IDs, revisioned optimistic concurrency, and the
/// archive guard against an active enrollment. The congregation reference
/// counters (`unarchivedStudents`) are dropped.
library;

import '../../domain/common.dart';
import '../../domain/validation.dart';
import '../direct_store.dart';
import '../error_mapper.dart';
import '../transport_support.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

const Set<String> _addressFields = <String>{
  'street',
  'district',
  'city',
  'postalCode',
  'stateCode',
};

/// The students slice of the direct-transport dispatch table.
Map<String, DirectOperationHandler> studentsHandlers() =>
    <String, DirectOperationHandler>{
      'saveStudent': saveStudentHandler,
      'setStudentArchived': setStudentArchivedHandler,
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

String _requireCongregationId(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw validationFailure(
      'O aluno requer a congregação.',
      fieldErrors: <String, String>{'congregationId': 'congregaçãoId é obrigatória.'},
    );
  }
  return value.trim();
}

String? _optionalTrimmed(Object? value, {required String field}) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw validationFailure('Valor inválido.', fieldErrors: <String, String>{
      field: 'Valor inválido.',
    });
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _optionalBool(Object? value, {required String field}) {
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    throw validationFailure('Valor inválido.', fieldErrors: <String, String>{
      field: 'Valor inválido.',
    });
  }
  return value;
}

String? _normalizePhone(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is! String) {
    throw validationFailure('Telefone inválido.', fieldErrors: <String, String>{
      'phone': 'Telefone inválido.',
    });
  }
  try {
    return normalizeBrazilianPhone(raw);
  } on FormatException catch (error) {
    final String message = error.message;
    throw validationFailure(message, fieldErrors: <String, String>{
      'phone': message,
    });
  }
}

String? _viewBirthDate(Object? raw, DateTime nowUtc) {
  if (raw == null) {
    return null;
  }
  if (raw is! String) {
    throw validationFailure(
      'Data de nascimento inválida.',
      fieldErrors: <String, String>{'birthDate': 'Data de nascimento inválida.'},
    );
  }
  if (raw.trim().isEmpty) {
    return null;
  }
  final CalendarDate date;
  try {
    date = CalendarDate.parse(raw);
  } on FormatException {
    throw validationFailure(
      'Data de nascimento inválida.',
      fieldErrors: <String, String>{'birthDate': 'Data de nascimento inválida.'},
    );
  }
  final String? error = validateBirthDate(date, nowUtc: nowUtc);
  if (error != null) {
    throw validationFailure(error, fieldErrors: <String, String>{
      'birthDate': error,
    });
  }
  return date.toIso8601String();
}

String? _optionalText(Object? raw, {required String field}) {
  final String? trimmed = _optionalTrimmed(raw, field: field);
  final String? error = validateOptionalText(
    trimmed,
    maxLength: optionalTextMaxLength,
  );
  if (error != null) {
    throw validationFailure(error, fieldErrors: <String, String>{
      field: error,
    });
  }
  return trimmed;
}

/// Normalizes the optional address map. Empty or absent maps become null.
JsonMap? _normalizeAddress(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is! Map) {
    throw validationFailure('Endereço inválido.', fieldErrors: <String, String>{
      'address': 'Endereço inválido.',
    });
  }
  for (final Object? key in raw.keys) {
    if (key is! String || !_addressFields.contains(key)) {
      throw validationFailure('Endereço inválido.', fieldErrors: <String, String>{
        'address': 'Endereço inválido.',
      });
    }
  }
  final Map<String, Object?> source = Map<String, Object?>.from(raw);
  final String? street = _optionalTrimmed(source['street'], field: 'address.street');
  final String? district = _optionalTrimmed(
    source['district'],
    field: 'address.district',
  );
  final String? city = _optionalTrimmed(source['city'], field: 'address.city');
  final String? postalCode = _optionalTrimmed(
    source['postalCode'],
    field: 'address.postalCode',
  );
  final String? stateCode = _optionalTrimmed(
    source['stateCode'],
    field: 'address.stateCode',
  );
  final String? error = validateAddressFields(
    street: street,
    district: district,
    city: city,
    postalCode: postalCode,
    stateCode: stateCode,
  );
  if (error != null) {
    throw validationFailure(error, fieldErrors: <String, String>{
      'address': error,
    });
  }
  final JsonMap normalized = <String, Object?>{
    'street': street,
    'district': district,
    'city': city,
    'postalCode': postalCode,
    'stateCode': stateCode,
  };
  final bool hasValue = normalized.values.any((Object? value) => value != null);
  return hasValue ? normalized : null;
}

/// Archived congregations are read-only except restoration, so student
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

Future<({JsonMap document, String path})> _locateStoredStudent(
  DirectTransaction tx,
  String congregationId,
  String studentId,
) async {
  final String path = StorePaths.student(congregationId, studentId);
  final JsonMap? document = await tx.read(path);
  if (document == null || document['congregationId'] != congregationId) {
    throw notFoundFailure(kNotFoundMessage);
  }
  return (document: document, path: path);
}

Future<JsonMap> saveStudentHandler(
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
  final String? education = _optionalText(payload['education'], field: 'education');
  final String? maritalStatus = _optionalText(
    payload['maritalStatus'],
    field: 'maritalStatus',
  );
  final bool? waterBaptized = _optionalBool(payload['waterBaptized'],
      field: 'waterBaptized');
  final bool? wantsBaptism = _optionalBool(payload['wantsBaptism'],
      field: 'wantsBaptism');
  final String? contradiction = validateBaptismAnswers(
    waterBaptized: waterBaptized,
    wantsBaptism: wantsBaptism,
  );
  if (contradiction != null) {
    throw validationFailure(contradiction, fieldErrors: <String, String>{
      'waterBaptized': contradiction,
    });
  }
  final String? phoneE164 = _normalizePhone(payload['phone']);
  final String? birthDate = _viewBirthDate(payload['birthDate'], context.now);
  final JsonMap? address = _normalizeAddress(payload['address']);
  final bool? newConvert = _optionalBool(payload['newConvert'], field: 'newConvert');
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
  final String path = StorePaths.student(congregationId, id);

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);
    final JsonMap? stored = await tx.read(path);
    if (isCreate) {
      if (stored != null) {
        throw conflictFailure(kConflictMessage);
      }
      final JsonMap document = withRecordMeta(
        base: <String, Object?>{
          'id': id,
          'name': trimmed,
          'normalizedName': normalized,
          'congregationId': congregationId,
          'phoneE164': phoneE164,
          'birthDate': birthDate,
          'address': address,
          'education': education,
          'maritalStatus': maritalStatus,
          'newConvert': newConvert,
          'waterBaptized': waterBaptized,
          'wantsBaptism': wantsBaptism,
          'archived': false,
        },
        now: context.now,
        uid: context.uid,
        revision: 1,
      );
      await tx.write(path, document);
      return <String, Object?>{'id': id, 'revision': 1};
    }

    final ({JsonMap document, String path}) located = await _locateStoredStudent(
      tx,
      congregationId,
      id,
    );
    if (located.document['archived'] == true) {
      throw conflictFailure('O aluno está arquivado; restaure-o antes de editar.');
    }
    _assertRevision(located.document, expectedRevision);
    final JsonMap next = _revised(
      located.document,
      changes: <String, Object?>{
        'name': trimmed,
        'normalizedName': normalized,
        'phoneE164': phoneE164,
        'birthDate': birthDate,
        'address': address,
        'education': education,
        'maritalStatus': maritalStatus,
        'newConvert': newConvert,
        'waterBaptized': waterBaptized,
        'wantsBaptism': wantsBaptism,
      },
      now: context.now,
      uid: context.uid,
    );
    await tx.write(located.path, next);
    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}

Future<JsonMap> setStudentArchivedHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String congregationId = _requireCongregationId(payload['congregationId']);
  final String id = requirePayloadString(payload, 'id');
  final bool archived = requirePayloadBool(payload, 'archived');
  final int expectedRevision = requirePayloadInt(payload, 'expectedRevision');
  if (expectedRevision < 1) {
    throw validationFailure('expectedRevision deve ser um inteiro positivo.');
  }

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    await _assertActiveCongregation(tx, congregationId);
    final ({JsonMap document, String path}) located = await _locateStoredStudent(
      tx,
      congregationId,
      id,
    );
    final JsonMap stored = located.document;
    if ((stored['archived'] == true) == archived) {
      return <String, Object?>{'id': id, 'revision': _revisionOf(stored)};
    }
    if (archived) {
      final JsonMap? enrollmentReference = await tx.read(
        'congregations/$congregationId/activeEnrollmentRefs/$id',
      );
      if (enrollmentReference != null) {
        throw conflictFailure(
          'O aluno tem uma matrícula ativa e não pode ser arquivado.',
        );
      }
    }
    _assertRevision(stored, expectedRevision);
    final JsonMap next = _revised(
      stored,
      changes: <String, Object?>{'archived': archived},
      now: context.now,
      uid: context.uid,
    );
    await tx.write(located.path, next);
    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}