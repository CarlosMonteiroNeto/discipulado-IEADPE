import 'package:discipulado_ieadpe/data/firebase_gateway.dart';
import 'package:discipulado_ieadpe/data/query_codec.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingTransport implements FirebaseTransport {
  final List<QueryPlan> plans = <QueryPlan>[];
  TransportPage page = const TransportPage(items: <JsonMap>[]);

  @override
  Future<JsonMap?> getDocument(String path) async => null;

  @override
  Future<TransportPage> runQuery(QueryPlan plan) async {
    plans.add(plan);
    return page;
  }

  @override
  Future<JsonMap> callFunction(String operation, JsonMap payload) async =>
      const <String, Object?>{};
}

void main() {
  const QueryCodec codec = QueryCodec();

  group('QueryPlan.namePrefix', () {
    test('carries the prefix normalized like the stored order key', () {
      final QueryPlan plan = codec.plan(
        const QueryRequest(
          resource: QueryResource.directory,
          namePrefix: '  Aná ',
        ),
      );
      expect(plan.namePrefix, 'ana');
    });

    test('is null when the request has no prefix', () {
      final QueryPlan plan = codec.plan(
        const QueryRequest(resource: QueryResource.directory),
      );
      expect(plan.namePrefix, isNull);
      expect(prefixRangeFor(plan), isNull);
    });

    test('builds an inclusive lower and exclusive upper range', () {
      final QueryPlan plan = codec.plan(
        const QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          namePrefix: 'jo',
        ),
      );
      final PrefixRange range = prefixRangeFor(plan)!;
      expect(range.lower, 'jo');
      expect(range.upper, 'jo\uf8ff');
    });
  });

  group('cursor identity binds the normalized prefix', () {
    String cursorForPrefix(String rawPrefix) {
      final QueryPlan plan = codec.plan(
        QueryRequest(resource: QueryResource.directory, namePrefix: rawPrefix),
      );
      return codec.encodeCursor(
        QueryCursor(
          resource: QueryResource.directory,
          filterFingerprint: plan.filterFingerprint,
          orderBy: plan.orderBy,
          lastId: 'd1',
          lastSortValue: 'ana',
        ),
      );
    }

    test('accepts the same prefix regardless of raw casing and spacing', () {
      final String cursor = cursorForPrefix('Aná');
      expect(
        () => codec.verifyCursor(
          cursor,
          const QueryRequest(
            resource: QueryResource.directory,
            namePrefix: 'ana',
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects a cursor minted under a prefix when replayed without it', () {
      final String cursor = cursorForPrefix('ana');
      expect(
        () => codec.verifyCursor(
          cursor,
          const QueryRequest(resource: QueryResource.directory),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('rejects a different prefix', () {
      final String cursor = cursorForPrefix('ana');
      expect(
        () => codec.verifyCursor(
          cursor,
          const QueryRequest(
            resource: QueryResource.directory,
            namePrefix: 'bob',
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('FirebaseGateway prefix transport', () {
    test(
      'hands the prefix to the transport and preserves it across a page',
      () async {
        final _RecordingTransport transport = _RecordingTransport()
          ..page = const TransportPage(
            items: <JsonMap>[
              <String, Object?>{'id': 'd1', 'normalizedName': 'ana'},
            ],
          );
        final FirebaseGateway gateway = FirebaseGateway(transport: transport);

        final PageResult first = await gateway.query(
          const QueryRequest(
            resource: QueryResource.directory,
            namePrefix: 'ana',
            limit: 1,
          ),
        );
        expect(transport.plans.single.namePrefix, 'ana');
        expect(first.nextCursor, isNotNull);

        await gateway.query(
          QueryRequest(
            resource: QueryResource.directory,
            namePrefix: 'ana',
            limit: 1,
            cursor: first.nextCursor,
          ),
        );
        expect(transport.plans.last.namePrefix, 'ana');
        expect(transport.plans.last.cursor, first.nextCursor);
      },
    );

    test('does not accept a prefixed cursor for an unprefixed query', () async {
      final _RecordingTransport transport = _RecordingTransport()
        ..page = const TransportPage(
          items: <JsonMap>[
            <String, Object?>{'id': 'd1', 'normalizedName': 'ana'},
          ],
        );
      final FirebaseGateway gateway = FirebaseGateway(transport: transport);
      final PageResult first = await gateway.query(
        const QueryRequest(
          resource: QueryResource.directory,
          namePrefix: 'ana',
          limit: 1,
        ),
      );

      await expectLater(
        gateway.query(
          QueryRequest(
            resource: QueryResource.directory,
            limit: 1,
            cursor: first.nextCursor,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
