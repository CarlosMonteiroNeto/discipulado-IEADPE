import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/backup/backup_repository.dart';
import 'package:ieadpe_converts/features/backup/backup_models.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';

class MemoryProgress implements ImportProgressStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class ImportTransport implements ImportRpcGateway {
  final operations = <String>[];
  bool fail = true;
  String owner = '11111111-1111-1111-1111-111111111111';
  String status = 'created';
  bool invalidate = false;
  String? error;
  Map<String, Object?>? lastPayload;
  @override
  Future<Map<String, dynamic>> importRow(
    String operation,
    Map<String, Object?> payload,
  ) async {
    operations.add(operation);
    lastPayload = payload;
    if (invalidate) boundary.invalidate();
    if (error != null) throw DataFailure(error!);
    if (fail) throw const DataFailure('unavailable');
    return {
      'id': '22222222-2222-2222-2222-222222222222',
      'status': status,
      'warning': 'unknown_congregation',
    };
  }

  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => '${boundary.generation}:$owner';
  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => [];
  @override
  Future<MutationResult<String>> command(
    String name,
    String operation,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

ImportPreview sample() => ImportPreview(
  version: 2,
  rows: [
    BackupRow(
      2,
      ConvertRecord(
        id: '',
        internalId: 'legacy-test',
        name: 'Synthetic',
        landmark: 'Square',
        gender: Gender.male,
        conversionDate: DateOnly.parse('2020-01-01'),
        worshipType: 'Oração',
      ),
      'Unknown',
    ),
  ],
  diagnostics: [],
);
void main() {
  test(
    'diagnostic rows count once and progress includes excluded rows',
    () async {
      final transport = ImportTransport()..fail = false;
      final preview = ImportPreview(
        version: 2,
        rows: sample().rows,
        diagnostics: [
          const ImportDiagnostic(3, 'id_interno', 'duplicate_id'),
          const ImportDiagnostic(3, 'nome', 'required'),
          const ImportDiagnostic(4, 'id_interno', 'duplicate_id'),
        ],
      );
      final result = await BackupRepository(
        transport,
        MemoryProgress(),
      ).importRows(preview).toList();
      expect(result.last.errors, 1);
      expect(result.last.skipped, 1);
      expect(result.last.processed, 3);
    },
  );

  test('operations belong to the authenticated account, never shared by file alone', () async {
    final transport = ImportTransport(), store = MemoryProgress();
    await BackupRepository(transport, store).importRows(sample()).toList();
    transport.owner = '33333333-3333-3333-3333-333333333333';
    await BackupRepository(transport, store).importRows(sample()).toList();
    expect(transport.operations[0], isNot(transport.operations[1]));
    expect(store.values, hasLength(2));
    expect(store.values.toString(), isNot(contains('Synthetic')));
  });
  test(
    'duplicate and tombstone receipts count skipped rather than created',
    () async {
      for (final status in ['duplicate', 'tombstone']) {
        final transport = ImportTransport()
          ..fail = false
          ..status = status;
        final result = await BackupRepository(
          transport,
          MemoryProgress(),
        ).importRows(sample()).toList();
        expect(result.last.created, 0);
        expect(result.last.skipped, 1);
        expect(
          transport.lastPayload,
          containsPair('internal_id', 'legacy-test'),
        );
        expect(transport.lastPayload, isNot(contains('id')));
      }
    },
  );
  test(
    'boundary invalidation prevents progress publication after sent row',
    () async {
      final transport = ImportTransport()
        ..fail = false
        ..invalidate = true;
      final events = <ImportProgress>[];
      await expectLater(
        BackupRepository(
          transport,
          MemoryProgress(),
        ).importRows(sample()).forEach(events.add),
        throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
      );
      expect(events, isEmpty);
    },
  );
  test(
    'invalid row is counted and independent valid rows still finish',
    () async {
      final transport = ImportTransport()
        ..fail = false
        ..error = 'invalid';
      final result = await BackupRepository(
        transport,
        MemoryProgress(),
      ).importRows(sample()).toList();
      expect(result.last.errors, 1);
      expect(result.last.created, 0);
      expect(result.last.done, true);
    },
  );
  test(
    'safe reselection retries same operation and reconciles created count',
    () async {
      final transport = ImportTransport(), store = MemoryProgress();
      await BackupRepository(transport, store).importRows(sample()).toList();
      expect(store.values, isNotEmpty);
      transport.fail = false;
      final result = await BackupRepository(
        transport,
        store,
      ).importRows(sample()).toList();
      expect(transport.operations.length, 2);
      expect(transport.operations[0], transport.operations[1]);
      expect(result.last.created, 1);
      expect(result.last.warning, 'unknown_congregation');
      expect(result.last.done, true);
      expect(store.values, isEmpty);
    },
  );
  test(
    'import reports every validated row instead of silently succeeding empty',
    () async {
      final result = await BackupRepository(
        ImportTransport(),
        MemoryProgress(),
      ).importRows(sample()).toList();
      expect(result, isNotEmpty);
      expect(result.last.errorCode, 'unavailable');
    },
  );
}
