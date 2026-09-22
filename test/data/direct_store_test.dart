import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryDirectStore', () {
    test('round-trips read, write and delete', () async {
      final DirectStore store = InMemoryDirectStore();
      expect(await store.read('a/b'), isNull);

      await store.write('a/b', <String, Object?>{'id': 'b', 'name': 'B'});
      expect(await store.read('a/b'), <String, Object?>{'id': 'b', 'name': 'B'});

      await store.delete('a/b');
      expect(await store.read('a/b'), isNull);
    });

    test('keeps written documents isolated from later mutation', () async {
      final DirectStore store = InMemoryDirectStore();
      final JsonMap data = <String, Object?>{'id': 'b', 'name': 'B'};
      await store.write('a/b', data);
      data['name'] = 'mutated';
      expect((await store.read('a/b'))!['name'], 'B');
    });

    test('queries a collection with filters, ordering and a limit', () async {
      final DirectStore store = InMemoryDirectStore(<String, JsonMap>{
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
          'name': 'Carla',
          'normalizedName': 'carla',
          'archived': true,
        },
      });

      final List<JsonMap> page = await store.query(
        const StoreQuery(
          collection: 'congregations/c1/students',
          filters: <String, Object?>{'archived': false},
          orderBy: 'normalizedName',
          limit: 1,
        ),
      );
      expect(page.map((JsonMap item) => item['id']), <String>['s1']);

      final List<JsonMap> all = await store.query(
        const StoreQuery(
          collection: 'congregations/c1/students',
          orderBy: 'normalizedName',
        ),
      );
      expect(all.map((JsonMap item) => item['id']), <String>['s1', 's2', 's3']);
    });

    test('queries a collection group scoped by field', () async {
      final DirectStore store = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1/sessions/x': <String, Object?>{
          'id': 'x',
          'congregationId': 'c1',
          'status': 'open',
        },
        'congregations/c2/sessions/y': <String, Object?>{
          'id': 'y',
          'congregationId': 'c2',
          'status': 'open',
        },
      });

      final List<JsonMap> scoped = await store.query(
        const StoreQuery(
          collection: 'sessions',
          group: true,
          filters: <String, Object?>{'congregationId': 'c1'},
        ),
      );
      expect(scoped.map((JsonMap item) => item['id']), <String>['x']);
    });

    test('transaction commits staged writes and deletes atomically', () async {
      final DirectStore store = InMemoryDirectStore(<String, JsonMap>{
        'a/keep': <String, Object?>{'id': 'keep', 'v': 1},
        'a/remove': <String, Object?>{'id': 'remove'},
      });

      await store.runTransaction<String>((DirectTransaction tx) async {
        expect((await tx.read('a/keep'))!['v'], 1);
        await tx.write('a/new', <String, Object?>{'id': 'new'});
        await tx.delete('a/remove');
        return 'ok';
      });

      expect(await store.read('a/new'), <String, Object?>{'id': 'new'});
      expect(await store.read('a/remove'), isNull);
    });

    test('forbids reading a document staged after a write, like the web SDK', () async {
      final DirectStore store = InMemoryDirectStore();
      await expectLater(
        store.runTransaction<void>((DirectTransaction tx) async {
          await tx.write('a/b', <String, Object?>{'id': 'b', 'v': 1});
          await tx.read('a/b');
        }),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('all reads to be executed before all writes'),
          ),
        ),
      );
    });

    test('transaction rolls back staged writes when the work throws', () async {
      final DirectStore store = InMemoryDirectStore(<String, JsonMap>{
        'a/keep': <String, Object?>{'id': 'keep', 'v': 1},
      });

      await expectLater(
        store.runTransaction<void>((DirectTransaction tx) async {
          await tx.write('a/keep', <String, Object?>{'id': 'keep', 'v': 2});
          await tx.write('a/new', <String, Object?>{'id': 'new'});
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );

      expect((await store.read('a/keep'))!['v'], 1);
      expect(await store.read('a/new'), isNull);
    });
  });
}
