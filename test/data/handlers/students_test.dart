import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/handlers/students.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

const String _studentUuid = '1f2e4321-abcd-46ae-9f0e-6c7f1a2b3c4d';
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

JsonMap studentPayload({
  String id = _studentUuid,
  String congregationId = 'c1',
  String name = 'Ana Souza',
  Object? phone,
  Object? birthDate,
  Object? address,
  Object? education,
  Object? maritalStatus,
  Object? newConvert,
  Object? waterBaptized,
  Object? wantsBaptism,
  int? expectedRevision,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': congregationId,
      'name': name,
      'phone': phone,
      'birthDate': birthDate,
      'address': address,
      'education': education,
      'maritalStatus': maritalStatus,
      'newConvert': newConvert,
      'waterBaptized': waterBaptized,
      'wantsBaptism': wantsBaptism,
      'requestId': 'req-x',
      'expectedRevision': ?expectedRevision,
    };

JsonMap seededStudent({
  String id = _studentUuid,
  String congregationId = 'c1',
  String name = 'Ana Souza',
  bool archived = false,
  int revision = 1,
}) =>
    <String, Object?>{
      'id': id,
      'name': name,
      'normalizedName': 'ana souza',
      'congregationId': congregationId,
      'phoneE164': '+5581991112233',
      'birthDate': '1995-05-10',
      'address': <String, Object?>{
        'street': 'Rua das Flores',
        'district': 'Centro',
        'city': 'Ipojuca',
        'postalCode': '55600000',
        'stateCode': 'PE',
      },
      'education': 'Ensino médio',
      'maritalStatus': 'Solteira',
      'newConvert': true,
      'waterBaptized': false,
      'wantsBaptism': null,
      'archived': archived,
      'revision': revision,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededCongregation({String id = 'c1', bool active = true}) =>
    <String, Object?>{
      'id': id,
      'name': id == 'c1' ? 'Abra' : 'Camboas',
      'normalizedName': id == 'c1' ? 'abra' : 'camboas',
      'active': active,
      'revision': 1,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

void main() {
  group('students handlers', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;
    late HandlerContext context;

    setUp(() {
      store = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/students/$_studentUuid': seededStudent(),
      });
      handlers = studentsHandlers();
      context = contextWith(store);
    });

    test('exposes saveStudent and setStudentArchived', () {
      expect(
        handlers.keys,
        containsAll(<String>['saveStudent', 'setStudentArchived']),
      );
    });

    test('create writes the full record and returns revision 1', () async {
      final JsonMap result = await handlers['saveStudent']!(
        context,
        studentPayload(
          id: _secondUuid,
          phone: '81991112233',
          birthDate: '1995-05-10',
          address: <String, Object?>{
            'street': 'Rua das Flores',
            'district': 'Centro',
            'city': 'Ipojuca',
            'postalCode': '55600000',
            'stateCode': 'PE',
          },
          education: '  Ensino médio  ',
          maritalStatus: '',
          newConvert: true,
          waterBaptized: false,
          wantsBaptism: null,
        ),
      );

      expect(result, <String, Object?>{
        'id': _secondUuid,
        'revision': 1,
      });
      final JsonMap? record = await store.read(
        'congregations/c1/students/$_secondUuid',
      );
      expect(record?['name'], 'Ana Souza');
      expect(record?['normalizedName'], 'ana souza');
      expect(record?['congregationId'], 'c1');
      expect(record?['phoneE164'], '+5581991112233');
      expect(record?['birthDate'], '1995-05-10');
      expect(record?['education'], 'Ensino médio');
      expect(record?['maritalStatus'], isNull);
      expect(record?['newConvert'], true);
      expect(record?['waterBaptized'], false);
      expect(record?['wantsBaptism'], isNull);
      expect(record?['archived'], false);
      expect(record?['revision'], 1);
      expect(record?['createdAt'], record?['updatedAt']);
      expect(record?['updatedBy'], 'u1');
      expect(addressOf(record), isNotNull);
    });

    test('rejects a non-UUID id on create', () async {
      await expectLater(
        handlers['saveStudent']!(
          context,
          studentPayload(id: 'not-a-uuid'),
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

    test('rejects a blank or short display name', () async {
      await expectLater(
        handlers['saveStudent']!(context, studentPayload(name: ' ')),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects a malformed phone', () async {
      await expectLater(
        handlers['saveStudent']!(context, studentPayload(phone: 'abc')),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects a future birth date', () async {
      await expectLater(
        handlers['saveStudent']!(
          context,
          studentPayload(id: _secondUuid, birthDate: '3000-01-01'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
      expect(await store.read('congregations/c1/students/$_secondUuid'), isNull);
    });

    test('rejects contradictory baptism answers', () async {
      await expectLater(
        handlers['saveStudent']!(
          context,
          studentPayload(
            id: _secondUuid,
            waterBaptized: true,
            wantsBaptism: true,
          ),
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

    test('rejects an address with an invalid postal code or UF', () async {
      await expectLater(
        handlers['saveStudent']!(
          context,
          studentPayload(
            id: _secondUuid,
            address: <String, Object?>{
              'street': 'Rua das Flores',
              'district': 'Centro',
              'city': 'Ipojuca',
              'postalCode': '123',
              'stateCode': 'PE',
            },
          ),
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
        handlers['saveStudent']!(
          context,
          studentPayload(
            id: _secondUuid,
            address: <String, Object?>{
              'street': 'Rua das Flores',
              'district': 'Centro',
              'city': 'Ipojuca',
              'postalCode': '55600000',
              'stateCode': 'XX',
            },
          ),
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

    test('an all-empty address is stored as null', () async {
      await handlers['saveStudent']!(
        context,
        studentPayload(
          id: _secondUuid,
          address: <String, Object?>{
            'street': '',
            'district': '',
            'city': '',
            'postalCode': '',
            'stateCode': '',
          },
        ),
      );

      final JsonMap? record = await store.read(
        'congregations/c1/students/$_secondUuid',
      );
      expect(record?['address'], isNull);
    });

    test('rename preserves identity and createdAt and bumps revision',
        () async {
      final JsonMap result = await handlers['saveStudent']!(
        context,
        studentPayload(
          name: 'Ana Souza Lima',
          expectedRevision: 1,
        ),
      );

      expect(result, <String, Object?>{
        'id': _studentUuid,
        'revision': 2,
      });
      final JsonMap? record = await store.read(
        'congregations/c1/students/$_studentUuid',
      );
      expect(record?['id'], _studentUuid);
      expect(record?['name'], 'Ana Souza Lima');
      expect(record?['normalizedName'], 'ana souza lima');
      expect(record?['createdAt'], '2025-01-01T12:00:00.000Z');
      expect(record?['revision'], 2);
      expect(record?['updatedBy'], 'u1');
    });

    test('rejects a stale expected revision on rename', () async {
      await expectLater(
        handlers['saveStudent']!(
          context,
          studentPayload(name: 'Ana Souza Lima', expectedRevision: 7),
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

    test('rejects editing an archived student', () async {
      await handlers['setStudentArchived']!(
        context,
        <String, Object?>{
          'id': _studentUuid,
          'congregationId': 'c1',
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-arch',
        },
      );
      await expectLater(
        handlers['saveStudent']!(
          context,
          studentPayload(name: 'Ana Souza Lima', expectedRevision: 2),
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

    test('setStudentArchived archive then restore flips the flag with revisions',
        () async {
      final JsonMap archived = await handlers['setStudentArchived']!(
        context,
        <String, Object?>{
          'id': _studentUuid,
          'congregationId': 'c1',
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-arch',
        },
      );
      expect(archived, <String, Object?>{'id': _studentUuid, 'revision': 2});
      JsonMap? record = await store.read('congregations/c1/students/$_studentUuid');
      expect(record?['archived'], true);
      expect(record?['revision'], 2);

      final JsonMap restored = await handlers['setStudentArchived']!(
        context,
        <String, Object?>{
          'id': _studentUuid,
          'congregationId': 'c1',
          'archived': false,
          'expectedRevision': 2,
          'requestId': 'req-restore',
        },
      );
      expect(restored, <String, Object?>{'id': _studentUuid, 'revision': 3});
      record = await store.read('congregations/c1/students/$_studentUuid');
      expect(record?['archived'], false);
      expect(record?['revision'], 3);
    });

    test('setStudentArchived is a no-op in the target state', () async {
      final JsonMap result = await handlers['setStudentArchived']!(
        context,
        <String, Object?>{
          'id': _studentUuid,
          'congregationId': 'c1',
          'archived': false,
          'expectedRevision': 1,
          'requestId': 'req-noop',
        },
      );

      expect(result['revision'], 1);
      final JsonMap? record = await store.read(
        'congregations/c1/students/$_studentUuid',
      );
      expect(record?['archived'], false);
      expect(record?['revision'], 1);
    });

    test('setStudentArchived missing record is a notFound failure', () async {
      await expectLater(
        handlers['setStudentArchived']!(
          context,
          <String, Object?>{
            'id': _secondUuid,
            'congregationId': 'c1',
            'archived': true,
            'expectedRevision': 1,
            'requestId': 'req-missing',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.notFound,
          ),
        ),
      );
    });

    test('refuses to archive a student with an active enrollment', () async {
      store.write(
        'congregations/c1/activeEnrollmentRefs/$_studentUuid',
        <String, Object?>{'studentId': _studentUuid, 'classId': 'cl1'},
      );

      await expectLater(
        handlers['setStudentArchived']!(
          context,
          <String, Object?>{
            'id': _studentUuid,
            'congregationId': 'c1',
            'archived': true,
            'expectedRevision': 1,
            'requestId': 'req-enr',
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
      final JsonMap? record = await store.read(
        'congregations/c1/students/$_studentUuid',
      );
      expect(record?['archived'], false);
    });

    test('refuses work inside a missing or archived congregation', () async {
      await expectLater(
        handlers['saveStudent']!(
          context,
          studentPayload(id: _secondUuid, congregationId: 'nope'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.notFound,
          ),
        ),
      );

      store.write('congregations/c2', seededCongregation(id: 'c2', active: false));
      await expectLater(
        handlers['saveStudent']!(
          context,
          studentPayload(id: _secondUuid, congregationId: 'c2'),
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

    test('writes nothing outside the congregation-scoped students collection',
        () async {
      await handlers['saveStudent']!(
        context,
        studentPayload(id: _secondUuid),
      );
      await handlers['setStudentArchived']!(
        context,
        <String, Object?>{
          'id': _studentUuid,
          'congregationId': 'c1',
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-arch2',
        },
      );

      final List<JsonMap> projections = await store.query(
        const StoreQuery(collection: 'directory', group: true),
      );
      expect(projections, isEmpty);
      final List<JsonMap> refs = await store.query(
        const StoreQuery(collection: 'activeEnrollmentRefs', group: true),
      );
      expect(refs, isEmpty);
    });
  });
}

JsonMap? addressOf(JsonMap? record) {
  final Object? raw = record?['address'];
  return raw is JsonMap ? raw : null;
}