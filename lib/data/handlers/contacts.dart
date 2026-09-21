/// Contact handlers for the direct transport (internal mode).
///
/// Mirrors `functions/src/contacts`: scoped contact records, per-scope
/// administrative role slots, teacher as a multi-holder role and the minimal
/// directory projection written atomically with the contact. Reference counts
/// and the teacher-class reference index are dropped.
library;

import '../../domain/common.dart';
import '../../domain/contact.dart';
import '../../domain/validation.dart';
import '../direct_store.dart';
import '../error_mapper.dart';
import '../transport_support.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

const Set<RoleCode> _multiHolderRoles = <RoleCode>{RoleCode.teacher};

bool _isAdministrativeRole(RoleCode role) => !_multiHolderRoles.contains(role);

/// The contacts slice of the direct-transport dispatch table.
Map<String, DirectOperationHandler> contactsHandlers() =>
    <String, DirectOperationHandler>{
      'saveContact': saveContactHandler,
      'setContactArchived': setContactArchivedHandler,
      'replaceRoleHolder': replaceRoleHolderHandler,
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

ContactScope _parseScope(Object? raw) {
  if (raw is! String) {
    throw validationFailure('Escopo de contato inválido.', fieldErrors: <String, String>{
      'scope': 'Escopo de contato inválido.',
    });
  }
  try {
    return ContactScope.fromWire(raw);
  } on DataFormatException {
    throw validationFailure('Escopo de contato inválido.', fieldErrors: <String, String>{
      'scope': 'Escopo de contato inválido.',
    });
  }
}

String _requireCongregationId(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw validationFailure(
      'Uma congregação é obrigatória para contatos da congregação.',
      fieldErrors: <String, String>{
        'congregationId': 'congregaçãoId é obrigatória.',
      },
    );
  }
  return value.trim();
}

RoleCode? _parseRoleCode(Object? raw, ContactScope scope) {
  if (raw == null || (raw is String && raw.isEmpty)) {
    return null;
  }
  if (raw is! String) {
    throw validationFailure('Papel desconhecido.', fieldErrors: <String, String>{
      'roleCode': 'Papel desconhecido.',
    });
  }
  final RoleCode code;
  try {
    code = RoleCode.fromWire(raw);
  } on DataFormatException {
    throw validationFailure('Papel desconhecido.', fieldErrors: <String, String>{
      'roleCode': 'Papel desconhecido.',
    });
  }
  if (code.scope != scope) {
    throw validationFailure(
      'Papel inválido para este escopo.',
      fieldErrors: <String, String>{
        'roleCode': 'Papel inválido para este escopo.',
      },
    );
  }
  return code;
}

RoleCode _requireRoleCode(Object? raw, ContactScope scope) {
  final RoleCode? code = _parseRoleCode(raw, scope);
  if (code == null) {
    throw validationFailure('roleCode é obrigatório.', fieldErrors: <String, String>{
      'roleCode': 'roleCode é obrigatório.',
    });
  }
  return code;
}

String _contactPath(ContactScope scope, String? congregationId, String id) {
  if (scope == ContactScope.supervision) {
    return StorePaths.supervisionContact(id);
  }
  return StorePaths.contact(congregationId!, id);
}

String _roleSlotPath(ContactScope scope, String? congregationId, RoleCode roleCode) {
  if (scope == ContactScope.supervision) {
    return StorePaths.supervisionRoleSlot(roleCode.wire);
  }
  return StorePaths.roleSlot(congregationId!, roleCode.wire);
}

/// Resolves the stored contact at its declared scope. A record found under the
/// other scope proves an attempt to change scope, which is rejected: scope is
/// immutable and IDs are never reused across scopes.
Future<JsonMap> _locateContact(
  DirectTransaction tx, {
  required ContactScope scope,
  String? congregationId,
  required String id,
}) async {
  final String primary = _contactPath(scope, congregationId, id);
  final JsonMap? stored = await tx.read(primary);
  if (stored != null) {
    return stored;
  }
  final String? alternative = scope == ContactScope.congregation
      ? StorePaths.supervisionContact(id)
      : (congregationId != null && congregationId.isNotEmpty
          ? StorePaths.contact(congregationId, id)
          : null);
  if (alternative != null && await tx.read(alternative) != null) {
    throw validationFailure(
      'O escopo do contato não pode mudar.',
      fieldErrors: <String, String>{
        'scope': 'O escopo do contato não pode mudar.',
      },
    );
  }
  throw notFoundFailure(kNotFoundMessage);
}

Future<void> _claimAdministrativeSlot(
  DirectTransaction tx, {
  required ContactScope scope,
  String? congregationId,
  required RoleCode roleCode,
  required String contactId,
  required DateTime now,
  required String uid,
}) async {
  final String path = _roleSlotPath(scope, congregationId, roleCode);
  final JsonMap? slot = await tx.read(path);
  if (slot == null) {
    await tx.write(
      path,
      withRecordMeta(
        base: <String, Object?>{
          'id': roleCode.wire,
          'scope': scope.wire,
          'congregationId': congregationId,
          'roleCode': roleCode.wire,
          'contactId': contactId,
        },
        now: now,
        uid: uid,
        revision: 1,
      ),
    );
    return;
  }
  final Object? holder = slot['contactId'];
  if (holder is String && holder.isNotEmpty && holder != contactId) {
    throw conflictFailure('Este papel administrativo já está ocupado.');
  }
  await tx.write(
    path,
    _revised(
      slot,
      changes: <String, Object?>{'contactId': contactId},
      now: now,
      uid: uid,
    ),
  );
}

Future<void> _releaseAdministrativeSlot(
  DirectTransaction tx, {
  required ContactScope scope,
  String? congregationId,
  required RoleCode roleCode,
  required String contactId,
  required DateTime now,
  required String uid,
}) async {
  final String path = _roleSlotPath(scope, congregationId, roleCode);
  final JsonMap? slot = await tx.read(path);
  if (slot == null || slot['contactId'] != contactId) {
    return;
  }
  await tx.write(
    path,
    _revised(
      slot,
      changes: <String, Object?>{'contactId': null},
      now: now,
      uid: uid,
    ),
  );
}

/// Writes the directory projection for an active contact and removes it for an
/// archived one, so private fields never leak and archived contacts have no
/// directory availability.
Future<void> _writeDirectoryProjection(
  DirectTransaction tx,
  JsonMap contact,
) async {
  final Object? id = contact['id'];
  if (id is! String || id.isEmpty) {
    return;
  }
  final String path = StorePaths.directory(id);
  if (contact['archived'] == true) {
    await tx.delete(path);
    return;
  }
  await tx.write(
    path,
    <String, Object?>{
      'id': id,
      'name': contact['name'],
      'normalizedName': contact['normalizedName'],
      'roleCode': contact['roleCode'],
      'scope': contact['scope'],
      'congregationId': contact['congregationId'],
      'phoneE164': contact['phoneE164'],
    },
  );
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

CalendarDate? _parseBirthDate(Object? raw, DateTime nowUtc) {
  if (raw == null) {
    return null;
  }
  if (raw is! String) {
    throw validationFailure(
      'Data de nascimento inválida.',
      fieldErrors: <String, String>{'birthDate': 'Data de nascimento inválida.'},
    );
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
  return date;
}

RoleCode? _storedRoleCode(JsonMap record) {
  final Object? raw = record['roleCode'];
  if (raw is! String) {
    return null;
  }
  try {
    return RoleCode.fromWire(raw);
  } on DataFormatException {
    return null;
  }
}

Future<JsonMap> saveContactHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String id = requirePayloadString(payload, 'id');
  final ContactScope scope = _parseScope(payload['scope']);
  final String? congregationId = scope == ContactScope.congregation
      ? _requireCongregationId(payload['congregationId'])
      : null;
  final String name = requirePayloadString(payload, 'name');
  final String? nameError = validateDisplayName(name);
  if (nameError != null) {
    throw validationFailure(nameError, fieldErrors: <String, String>{
      'name': nameError,
    });
  }
  final RoleCode? roleCode = _parseRoleCode(payload['roleCode'], scope);
  final String? phoneE164 = _normalizePhone(payload['phone']);
  final CalendarDate? birthDate = _parseBirthDate(payload['birthDate'], context.now);
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
  final String path = _contactPath(scope, congregationId, id);

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
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
          'scope': scope.wire,
          'congregationId': congregationId,
          'roleCode': roleCode?.wire,
          'phoneE164': phoneE164,
          'birthDate': birthDate?.toIso8601String(),
          'archived': false,
        },
        now: context.now,
        uid: context.uid,
        revision: 1,
      );
      await tx.write(path, document);
      if (roleCode != null && _isAdministrativeRole(roleCode)) {
        await _claimAdministrativeSlot(
          tx,
          scope: scope,
          congregationId: congregationId,
          roleCode: roleCode,
          contactId: id,
          now: context.now,
          uid: context.uid,
        );
      }
      await _writeDirectoryProjection(tx, document);
      return <String, Object?>{'id': id, 'revision': 1};
    }

    final JsonMap storedContact = await _locateContact(
      tx,
      scope: scope,
      congregationId: congregationId,
      id: id,
    );
    final bool scopeMatches =
        storedContact['scope'] == scope.wire &&
        (storedContact['congregationId'] is String
            ? storedContact['congregationId']
            : null) ==
            congregationId;
    if (!scopeMatches) {
      throw validationFailure(
        'O escopo do contato não pode mudar.',
        fieldErrors: <String, String>{
          'scope': 'O escopo do contato não pode mudar.',
        },
      );
    }
    if (storedContact['archived'] == true) {
      throw conflictFailure('O contato está arquivado; restaure-o antes de editar.');
    }
    _assertRevision(storedContact, expectedRevision);
    final RoleCode? previousRole = _storedRoleCode(storedContact);
    final JsonMap next = _revised(
      storedContact,
      changes: <String, Object?>{
        'name': trimmed,
        'normalizedName': normalized,
        'roleCode': roleCode?.wire,
        'phoneE164': phoneE164,
        'birthDate': birthDate?.toIso8601String(),
      },
      now: context.now,
      uid: context.uid,
    );
    if (previousRole != null &&
        previousRole != roleCode &&
        _isAdministrativeRole(previousRole)) {
      await _releaseAdministrativeSlot(
        tx,
        scope: scope,
        congregationId: congregationId,
        roleCode: previousRole,
        contactId: id,
        now: context.now,
        uid: context.uid,
      );
    }
    if (roleCode != null && _isAdministrativeRole(roleCode)) {
      await _claimAdministrativeSlot(
        tx,
        scope: scope,
        congregationId: congregationId,
        roleCode: roleCode,
        contactId: id,
        now: context.now,
        uid: context.uid,
      );
    }
    await tx.write(path, next);
    await _writeDirectoryProjection(tx, next);
    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}

Future<JsonMap> setContactArchivedHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String id = requirePayloadString(payload, 'id');
  final ContactScope scope = _parseScope(payload['scope']);
  final String? congregationId = scope == ContactScope.congregation
      ? _requireCongregationId(payload['congregationId'])
      : null;
  final bool archived = requirePayloadBool(payload, 'archived');
  final int expectedRevision = requirePayloadInt(payload, 'expectedRevision');
  if (expectedRevision < 1) {
    throw validationFailure('expectedRevision deve ser um inteiro positivo.');
  }

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    final JsonMap located = await _locateContact(
      tx,
      scope: scope,
      congregationId: congregationId,
      id: id,
    );
    final bool scopeMatches =
        located['scope'] == scope.wire &&
        (located['congregationId'] is String
            ? located['congregationId']
            : null) ==
            congregationId;
    if (!scopeMatches) {
      throw validationFailure(
        'O escopo do contato não pode mudar.',
        fieldErrors: <String, String>{
          'scope': 'O escopo do contato não pode mudar.',
        },
      );
    }
    if ((located['archived'] == true) == archived) {
      return <String, Object?>{'id': id, 'revision': _revisionOf(located)};
    }
    _assertRevision(located, expectedRevision);
    final RoleCode? previousRole = _storedRoleCode(located);
    final JsonMap next = _revised(
      located,
      changes: <String, Object?>{
        'archived': archived,
        'roleCode': null,
      },
      now: context.now,
      uid: context.uid,
    );
    if (previousRole != null && _isAdministrativeRole(previousRole)) {
      await _releaseAdministrativeSlot(
        tx,
        scope: scope,
        congregationId: congregationId,
        roleCode: previousRole,
        contactId: id,
        now: context.now,
        uid: context.uid,
      );
    }
    await tx.write(_contactPath(scope, congregationId, id), next);
    await _writeDirectoryProjection(tx, next);
    return <String, Object?>{'id': id, 'revision': _revisionOf(next)};
  });
}

Future<JsonMap> replaceRoleHolderHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final ContactScope scope = _parseScope(payload['scope']);
  final String? congregationId = scope == ContactScope.congregation
      ? _requireCongregationId(payload['congregationId'])
      : null;
  final RoleCode roleCode = _requireRoleCode(payload['roleCode'], scope);
  if (!_isAdministrativeRole(roleCode)) {
    throw validationFailure(
      'O papel de professor aceita vários titulares; a troca não é suportada.',
      fieldErrors: <String, String>{
        'roleCode': 'O papel de professor aceita vários titulares.',
      },
    );
  }
  final String previousContactId = requirePayloadString(payload, 'previousContactId');
  final int previousExpectedRevision = requirePayloadInt(
    payload,
    'previousExpectedRevision',
  );
  if (previousExpectedRevision < 1) {
    throw validationFailure('previousExpectedRevision deve ser um inteiro positivo.');
  }
  final String targetContactId = requirePayloadString(payload, 'id');
  final int targetExpectedRevision = requirePayloadInt(payload, 'expectedRevision');
  if (targetExpectedRevision < 1) {
    throw validationFailure('expectedRevision deve ser um inteiro positivo.');
  }

  return context.store.runTransaction<JsonMap>((DirectTransaction tx) async {
    final JsonMap previous = await _locateContact(
      tx,
      scope: scope,
      congregationId: congregationId,
      id: previousContactId,
    );
    final JsonMap target = await _locateContact(
      tx,
      scope: scope,
      congregationId: congregationId,
      id: targetContactId,
    );
    if (previous['archived'] == true || target['archived'] == true) {
      throw conflictFailure(
        'Contatos arquivados não podem ocupar ou receber um papel administrativo.',
      );
    }
    if (previous['roleCode'] != roleCode.wire) {
      throw validationFailure(
        'O titular anterior não ocupa este papel.',
        fieldErrors: <String, String>{
          'previousContactId': 'O titular anterior não ocupa este papel.',
        },
      );
    }
    final String slotPath = _roleSlotPath(scope, congregationId, roleCode);
    final JsonMap? slot = await tx.read(slotPath);
    final Object? holder = slot?['contactId'];
    if (holder is String && holder.isNotEmpty && holder != previousContactId) {
      throw conflictFailure('O titular do papel mudou desde o carregamento.');
    }
    final RoleCode? targetPreviousRole = _storedRoleCode(target);
    if (targetPreviousRole != null &&
        targetPreviousRole != roleCode &&
        _isAdministrativeRole(targetPreviousRole)) {
      await _releaseAdministrativeSlot(
        tx,
        scope: scope,
        congregationId: congregationId,
        roleCode: targetPreviousRole,
        contactId: targetContactId,
        now: context.now,
        uid: context.uid,
      );
    }
    _assertRevision(previous, previousExpectedRevision);
    _assertRevision(target, targetExpectedRevision);

    final JsonMap previousNext = _revised(
      previous,
      changes: <String, Object?>{'roleCode': null},
      now: context.now,
      uid: context.uid,
    );
    final JsonMap targetNext = _revised(
      target,
      changes: <String, Object?>{'roleCode': roleCode.wire},
      now: context.now,
      uid: context.uid,
    );
    if (slot != null) {
      await tx.write(
        slotPath,
        _revised(
          slot,
          changes: <String, Object?>{'contactId': targetContactId},
          now: context.now,
          uid: context.uid,
        ),
      );
    } else {
      await tx.write(
        slotPath,
        withRecordMeta(
          base: <String, Object?>{
            'id': roleCode.wire,
            'scope': scope.wire,
            'congregationId': congregationId,
            'roleCode': roleCode.wire,
            'contactId': targetContactId,
          },
          now: context.now,
          uid: context.uid,
          revision: 1,
        ),
      );
    }
    await tx.write(
      _contactPath(scope, congregationId, previousContactId),
      previousNext,
    );
    await tx.write(
      _contactPath(scope, congregationId, targetContactId),
      targetNext,
    );
    await _writeDirectoryProjection(tx, previousNext);
    await _writeDirectoryProjection(tx, targetNext);
    return <String, Object?>{
      'id': targetContactId,
      'revision': _revisionOf(targetNext),
      'previousContactId': previousContactId,
      'previousRevision': _revisionOf(previousNext),
    };
  });
}