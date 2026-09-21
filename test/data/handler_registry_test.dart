import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/firebase_gateway.dart';
import 'package:discipulado_ieadpe/data/firestore_direct_transport.dart';
import 'package:discipulado_ieadpe/data/handlers/registry.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exact direct-transport operation set the S11 repositories send. Every
/// name must resolve to exactly one handler in the composed registry.
const List<String> _directOperations = <String>[
  'saveCongregation',
  'setCongregationArchived',
  'saveContact',
  'replaceRoleHolder',
  'setContactArchived',
  'saveStudent',
  'setStudentArchived',
  'saveClass',
  'setClassStatus',
  'enrollStudent',
  'closeEnrollment',
  'createSession',
  'cancelSession',
  'saveAttendance',
  'getSessionAttendance',
  'getEnrollmentProgress',
  'getOverview',
  'listPendingSessions',
];

FirestoreDirectTransport _transportWith({DirectStore? store}) {
  final DirectStore backing =
      store ??
      InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1/students/s1': <String, Object?>{
          'id': 's1',
          'name': 'Ana',
          'normalizedName': 'ana',
          'archived': false,
        },
        'congregations/c1/students/s2': <String, Object?>{
          'id': 's2',
          'name': 'Bruno',
          'normalizedName': 'bruno',
          'archived': false,
        },
        'congregations/c1/students/s3': <String, Object?>{
          'id': 's3',
          'name': 'Bruna',
          'normalizedName': 'bruna',
          'archived': true,
        },
      });
  return FirestoreDirectTransport(
    store: backing,
    registry: composeHandlerRegistry(),
    uid: () => 'u1',
    now: () => DateTime.utc(2026, 9, 21, 12),
  );
}

void main() {
  group('composed handler registry', () {
    test('covers every S11 direct-transport operation exactly once', () {
      final Map<String, Object> registry = composeHandlerRegistry();
      for (final String operation in _directOperations) {
        expect(registry.containsKey(operation), isTrue, reason: operation);
      }
      expect(registry.length, _directOperations.length);
      expect(registry.keys.toSet().length, registry.length,
          reason: 'no duplicate operation keys');
    });
  });

  group('composed direct transport satisfies the gateway contract', () {
    test('get resolves through getDocument with the decoded document map',
        () async {
      final FirebaseGateway gateway =
          FirebaseGateway(transport: _transportWith());
      final JsonMap? document = await gateway.get(
        const RecordLocator(
          resource: QueryResource.students,
          id: 's1',
          congregationId: 'c1',
        ),
      );
      expect(document?['id'], 's1');
      expect(document?['normalizedName'], 'ana');
    });

    test('get resolves a missing document to null', () async {
      final FirebaseGateway gateway =
          FirebaseGateway(transport: _transportWith());
      final JsonMap? document = await gateway.get(
        const RecordLocator(
          resource: QueryResource.students,
          id: 'missing',
          congregationId: 'c1',
        ),
      );
      expect(document, isNull);
    });

    test('query resolves through runQuery with filters, ordering and the page',
        () async {
      final FirebaseGateway gateway =
          FirebaseGateway(transport: _transportWith());
      final PageResult page = await gateway.query(
        const QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          equalityFilters: <String, Object?>{'archived': false},
        ),
      );
      expect(page.items.map((JsonMap item) => item['id']), <String>[
        's1',
        's2',
      ]);
      expect(page.nextCursor, isNull);
    });

    test('query honors the name-prefix range via runQuery', () async {
      final FirebaseGateway gateway =
          FirebaseGateway(transport: _transportWith());
      final PageResult page = await gateway.query(
        const QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          namePrefix: 'bru',
        ),
      );
      expect(page.items.map((JsonMap item) => item['id']), <String>[
        's3',
        's2',
      ]);
      expect(page.nextCursor, isNull);
    });
  });
}