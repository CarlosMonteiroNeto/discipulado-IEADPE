import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/handlers/contacts.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

const String _contactUuid = '1f2e4321-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _secondUuid = '2a4c6e82-abcd-46ae-9f0e-6c7f1a2b3c4d';
HandlerContext contextWith(
  DirectStore store, {
  String uid = 'u1',
  DateTime? now,
}) =>
    HandlerContext(
      store: store,
      uid: uid,
      now: now ?? DateTime.utc(2026, 9, 21, 12),
    );

JsonMap contactPayload({
  String id = _contactUuid,
  String scope = 'congregation',
  String? congregationId = 'c1',
  String name = 'Ana Souza',
  String? roleCode,
  String? phone,
  String? birthDate,
}) =>
    <String, Object?>{
      'id': id,
      'scope': scope,
      'congregationId': congregationId,
      'name': name,
      'roleCode': roleCode,
      'phone': phone,
      'birthDate': birthDate,
      'requestId': 'req-x',
};

    void main() {
  group('contacts handlers', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;
    late HandlerContext context;

    setUp(() {
      store = InMemoryDirectStore();
      handlers = contactsHandlers();
      context = contextWith(store);
    });

    test('exposes the five contact mutations', () {
      expect(
        handlers.keys,
        containsAll(<String>[
          'saveContact',
          'setContactArchived',
          'replaceRoleHolder',
        ]),
      );
    });

    test('create writes the contact and the directory projection atomically',
        () async {
      final JsonMap result = await handlers['saveContact']!(
        context,
        contactPayload(
          id: _contactUuid,
          roleCode: 'teacher',
          phone: '81991112233',
          birthDate: '1995-05-10',
        ),
      );

      expect(result, <String, Object?>{
        'id': _contactUuid,
        'revision': 1,
      });
      final JsonMap? record = await store.read(
        'congregations/c1/contacts/$_contactUuid',
      );
      expect(record?['name'], 'Ana Souza');
      expect(record?['normalizedName'], 'ana souza');
      expect(record?['scope'], 'congregation');
      expect(record?['congregationId'], 'c1');
      expect(record?['roleCode'], 'teacher');
      expect(record?['phoneE164'], '+5581991112233');
      expect(record?['birthDate'], '1995-05-10');
      expect(record?['archived'], false);
      expect(record?['revision'], 1);

      final JsonMap? projection = await store.read('directory/$_contactUuid');
      expect(projection?['id'], _contactUuid);
      expect(projection?['name'], 'Ana Souza');
      expect(projection?['normalizedName'], 'ana souza');
      expect(projection?['roleCode'], 'teacher');
      expect(projection?['scope'], 'congregation');
      expect(projection?['congregationId'], 'c1');
      expect(projection?['phoneE164'], '+5581991112233');
      expect(projection?['birthDate'], isNull);
      expect(projection?['address'], isNull);
    });

    test('supervision contacts live under supervisionContacts', () async {
      await handlers['saveContact']!(
        context,
        contactPayload(
          id: _contactUuid,
          scope: 'supervision',
          congregationId: null,
          roleCode: 'campaignSupervisor',
        ),
      );

      final JsonMap? record = await store.read(
        'supervisionContacts/$_contactUuid',
      );
      expect(record?['congregationId'], isNull);
      expect(record?['scope'], 'supervision');
      expect(record?['roleCode'], 'campaignSupervisor');

      final JsonMap? projection = await store.read('directory/$_contactUuid');
      expect(projection?['scope'], 'supervision');
    });

    test('rejects a non-UUID id on create', () async {
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(id: 'not-a-uuid'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects an unknown scope', () async {
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(scope: 'parish'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('requires congregationId for congregation scope', () async {
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(congregationId: null),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects a role that does not belong to the scope', () async {
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(roleCode: 'campaignSupervisor'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects an unknown role code', () async {
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(roleCode: 'bishop'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects a malformed or non-Brazilian phone', () async {
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(phone: '123'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(phone: '+12025550123'),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('rejects a future birth date', () async {
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(birthDate: '2030-01-01'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rename preserves createdAt and bumps the revision', () async {
      await handlers['saveContact']!(
        context,
        contactPayload(roleCode: 'teacher'),
      );
      final JsonMap result = await handlers['saveContact']!(
        context,
        contactPayload(
          name: 'Ana Maria Souza',
          roleCode: 'teacher',
        )..['expectedRevision'] = 1,
      );

      expect(result['revision'], 2);
      final JsonMap? record = await store.read(
        'congregations/c1/contacts/$_contactUuid',
      );
      expect(record?['name'], 'Ana Maria Souza');
      expect(record?['normalizedName'], 'ana maria souza');
      expect(record?['revision'], 2);
      expect(record?['createdAt'], isNotNull);
      final JsonMap? projection = await store.read('directory/$_contactUuid');
      expect(projection?['name'], 'Ana Maria Souza');
    });

    test('rejects a stale expected revision', () async {
      await handlers['saveContact']!(context, contactPayload());
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload()..['expectedRevision'] = 9,
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('rejects editing an archived contact', () async {
      await handlers['saveContact']!(context, contactPayload());
      await handlers['setContactArchived']!(
        context,
        <String, Object?>{
          'id': _contactUuid,
          'scope': 'congregation',
          'congregationId': 'c1',
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-2',
        },
      );
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload()..['expectedRevision'] = 2,
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('rejects a scope change while locating the record', () async {
      await handlers['saveContact']!(
        context,
        contactPayload(
          scope: 'supervision',
          congregationId: null,
          roleCode: 'campaignSupervisor',
        ),
      );
      await expectLater(
        handlers['saveContact']!(
          context,
          contactPayload(roleCode: 'teacher')..['expectedRevision'] = 1,
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('claims a per-scope administrative slot on create', () async {
      await handlers['saveContact']!(
        context,
        contactPayload(roleCode: 'campaignLeader'),
      );

      final JsonMap? slot = await store.read(
        'congregations/c1/roleSlots/campaignLeader',
      );
      expect(slot?['id'], 'campaignLeader');
      expect(slot?['contactId'], _contactUuid);
      expect(slot?['scope'], 'congregation');
      expect(slot?['congregationId'], 'c1');
      expect(slot?['revision'], 1);
    });

    test('refuses to claim an already-held administrative slot', () async {
      await handlers['saveContact']!(
        context,
        contactPayload(id: _contactUuid, roleCode: 'campaignLeader'),
      );
      final DateTime now = DateTime.utc(2026, 9, 21, 13);
      await expectLater(
        handlers['saveContact']!(
          contextWith(store, now: now),
          contactPayload(
            id: _secondUuid,
            name: 'Bruno Lima',
            roleCode: 'campaignLeader',
          ),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('teacher role permits multiple holders and writes no slot', () async {
      await handlers['saveContact']!(context, contactPayload(roleCode: 'teacher'));
      await handlers['saveContact']!(
        context,
        contactPayload(
          id: _secondUuid,
          name: 'Bruno Lima',
          roleCode: 'teacher',
        ),
      );

      final JsonMap? slot = await store.read('congregations/c1/roleSlots/teacher');
      expect(slot, isNull);
    });

    test('role change releases the previous slot and claims the new one',
        () async {
      await handlers['saveContact']!(
        context,
        contactPayload(roleCode: 'campaignLeader'),
      );
      await handlers['saveContact']!(
        context,
        contactPayload(roleCode: 'discipleshipSecretary')..['expectedRevision'] = 1,
      );

      final JsonMap? oldSlot = await store.read(
        'congregations/c1/roleSlots/campaignLeader',
      );
      expect(oldSlot?['contactId'], isNull);
      final JsonMap? newSlot = await store.read(
        'congregations/c1/roleSlots/discipleshipSecretary',
      );
      expect(newSlot?['contactId'], _contactUuid);
      final JsonMap? record = await store.read(
        'congregations/c1/contacts/$_contactUuid',
      );
      expect(record?['roleCode'], 'discipleshipSecretary');
    });

    test('setContactArchived releases the slot and drops the projection',
        () async {
      await handlers['saveContact']!(
        context,
        contactPayload(roleCode: 'campaignLeader'),
      );
      final JsonMap result = await handlers['setContactArchived']!(
        context,
        <String, Object?>{
          'id': _contactUuid,
          'scope': 'congregation',
          'congregationId': 'c1',
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-3',
        },
      );

      expect(result['revision'], 2);
      final JsonMap? record = await store.read(
        'congregations/c1/contacts/$_contactUuid',
      );
      expect(record?['archived'], true);
      expect(record?['roleCode'], isNull);
      final JsonMap? slot = await store.read(
        'congregations/c1/roleSlots/campaignLeader',
      );
      expect(slot?['contactId'], isNull);
      expect(await store.read('directory/$_contactUuid'), isNull);
    });

    test('setContactArchived restore keeps the record unassigned', () async {
      await handlers['saveContact']!(context, contactPayload());
      await handlers['setContactArchived']!(
        context,
        <String, Object?>{
          'id': _contactUuid,
          'scope': 'congregation',
          'congregationId': 'c1',
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-4',
        },
      );
      final JsonMap restore = await handlers['setContactArchived']!(
        context,
        <String, Object?>{
          'id': _contactUuid,
          'scope': 'congregation',
          'congregationId': 'c1',
          'archived': false,
          'expectedRevision': 2,
          'requestId': 'req-5',
        },
      );

      expect(restore['revision'], 3);
      final JsonMap? record = await store.read(
        'congregations/c1/contacts/$_contactUuid',
      );
      expect(record?['archived'], false);
      expect(record?['roleCode'], isNull);
      expect(await store.read('directory/$_contactUuid'), isNotNull);
    });

    test('replaceRoleHolder validates both revisions and reassigns the slot',
        () async {
      await handlers['saveContact']!(
        context,
        contactPayload(id: _contactUuid, name: 'Ana Souza', roleCode: 'campaignLeader'),
      );
      await handlers['saveContact']!(
        context,
        contactPayload(id: _secondUuid, name: 'Bruno Lima'),
      );

      final JsonMap result = await handlers['replaceRoleHolder']!(
        context,
        <String, Object?>{
          'scope': 'congregation',
          'congregationId': 'c1',
          'roleCode': 'campaignLeader',
          'previousContactId': _contactUuid,
          'previousExpectedRevision': 1,
          'id': _secondUuid,
          'expectedRevision': 1,
          'requestId': 'req-6',
        },
      );

      expect(result['id'], _secondUuid);
      expect(result['revision'], 2);
      expect(result['previousContactId'], _contactUuid);
      expect(result['previousRevision'], 2);
      final JsonMap? previous = await store.read(
        'congregations/c1/contacts/$_contactUuid',
      );
      expect(previous?['roleCode'], isNull);
      final JsonMap? target = await store.read(
        'congregations/c1/contacts/$_secondUuid',
      );
      expect(target?['roleCode'], 'campaignLeader');
      final JsonMap? slot = await store.read(
        'congregations/c1/roleSlots/campaignLeader',
      );
      expect(slot?['contactId'], _secondUuid);
      expect(await store.read('directory/$_contactUuid'), isNotNull);
      expect(await store.read('directory/$_secondUuid'), isNotNull);
    });

    test('replaceRoleHolder rejects teacher roles', () async {
      await expectLater(
        handlers['replaceRoleHolder']!(
          context,
          <String, Object?>{
            'scope': 'congregation',
            'congregationId': 'c1',
            'roleCode': 'teacher',
            'previousContactId': _contactUuid,
            'previousExpectedRevision': 1,
            'id': _secondUuid,
            'expectedRevision': 1,
            'requestId': 'req-7',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('replaceRoleHolder rejects an archived previous holder', () async {
      await handlers['saveContact']!(
        context,
        contactPayload(id: _contactUuid, roleCode: 'campaignLeader'),
      );
      await handlers['setContactArchived']!(
        context,
        <String, Object?>{
          'id': _contactUuid,
          'scope': 'congregation',
          'congregationId': 'c1',
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-8',
        },
      );
      await handlers['saveContact']!(
        context,
        contactPayload(id: _secondUuid, name: 'Bruno Lima'),
      );

      await expectLater(
        handlers['replaceRoleHolder']!(
          context,
          <String, Object?>{
            'scope': 'congregation',
            'congregationId': 'c1',
            'roleCode': 'campaignLeader',
            'previousContactId': _contactUuid,
            'previousExpectedRevision': 2,
            'id': _secondUuid,
            'expectedRevision': 1,
            'requestId': 'req-9',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('replaceRoleHolder rejects a previous holder without the role',
        () async {
      await handlers['saveContact']!(
        context,
        contactPayload(id: _contactUuid, roleCode: 'campaignLeader'),
      );
      await handlers['saveContact']!(
        context,
        contactPayload(id: _secondUuid, name: 'Bruno Lima'),
      );

      await expectLater(
        handlers['replaceRoleHolder']!(
          context,
          <String, Object?>{
            'scope': 'congregation',
            'congregationId': 'c1',
            'roleCode': 'campaignLeader',
            'previousContactId': _secondUuid,
            'previousExpectedRevision': 1,
            'id': _contactUuid,
            'expectedRevision': 1,
            'requestId': 'req-10',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('replaceRoleHolder conflicts on a stale previous revision', () async {
      await handlers['saveContact']!(
        context,
        contactPayload(id: _contactUuid, roleCode: 'campaignLeader'),
      );
      await handlers['saveContact']!(
        context,
        contactPayload(id: _secondUuid, name: 'Bruno Lima'),
      );

      await expectLater(
        handlers['replaceRoleHolder']!(
          context,
          <String, Object?>{
            'scope': 'congregation',
            'congregationId': 'c1',
            'roleCode': 'campaignLeader',
            'previousContactId': _contactUuid,
            'previousExpectedRevision': 9,
            'id': _secondUuid,
            'expectedRevision': 1,
            'requestId': 'req-11',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });
  });
}
