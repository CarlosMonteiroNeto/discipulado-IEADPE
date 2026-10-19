import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/convert_repository.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';

const _congregationId = 'b0000000-0000-4000-8000-000000000001';
const _linkedConvertId = 'd0000000-0000-4000-8000-000000000001';
const _linkedPersonId = 'e0000000-0000-4000-8000-000000000001';
const _legacyConvertId = 'f0000000-0000-4000-8000-000000000001';

final _longName = List.filled(244, 'A').join();

Map<String, dynamic> _convert({
  required String id,
  required String? personId,
  required String? congregationId,
}) => {
  'id': id,
  'internal_id': id,
  'person_id': personId,
  'congregation_id': congregationId,
  'landmark': 'Praça',
  'gender': 'female',
  'conversion_date': '2026-01-02',
  'worship_type': '01 - Oração',
  'photo_url': null,
  'photo_asset_id': null,
  'age': 36,
  'last_visit_date': '2026-01-02',
  'was_visited_once': false,
  'visit_count': 0,
  'is_in_discipleship': false,
  'discipleship_start_date': null,
  'is_discipleship_completed': false,
  'is_deviated': false,
  'created_by': null,
  'created_at': '2026-01-02T12:00:00Z',
  'updated_at': '2026-01-02T12:00:00Z',
  'deleted_at': null,
  'revision': 3,
};

Map<String, dynamic> _linkedProjection() => {
  'convert': _convert(
    id: _linkedConvertId,
    personId: _linkedPersonId,
    congregationId: _congregationId,
  ),
  'person': {
    'id': _linkedPersonId,
    'congregation_id': _congregationId,
    'name': _longName,
    'normalized_name': _longName.toLowerCase(),
    'phone': '+5511999990000',
    'birth_date': '1990-02-28',
    'address': {
      'street': 'Rua A',
      'district': null,
      'city': null,
      'postal_code': null,
      'state_code': null,
    },
  },
  'person_revision': 7,
  'legacy_identity': null,
};

Map<String, dynamic> _legacyProjection() => {
  'convert': _convert(
    id: _legacyConvertId,
    personId: null,
    congregationId: null,
  ),
  'person': null,
  'person_revision': null,
  'legacy_identity': {
    'name': 'Pessoa legada sem congregação',
    'phone': null,
    'address': 'Endereço original',
  },
};

class _ReadGateway implements ReadRpcGateway {
  final boundary = ProtectedDataBoundary();
  final calls = <({String rpc, Map<String, Object?> parameters})>[];

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    calls.add((rpc: rpc, parameters: Map.of(parameters)));
    if (rpc == 'ministry_get_convert') return _legacyProjection();
    return {
      'items': [_linkedProjection(), _legacyProjection()],
      'next_cursor': null,
    };
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
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) => throw UnimplementedError();
}

void main() {
  test('convert list decodes canonical long names and keeps legacy snapshots distinct', () async {
    final gateway = _ReadGateway();
    final page = await ConvertRepository(gateway)
        .list(const ConvertQuery(), null);

    expect(page.items, hasLength(2));
    expect(page.items.first.name, _longName);
    expect(page.items.last.name, 'Pessoa legada sem congregação');
    expect(page.items.first.phone, '+5511999990000');
    expect(page.items.last.phone, isNull);
    expect(gateway.calls.single.rpc, 'ministry_list_converts');
  });

  test('convert detail uses the caller congregation and preserves unlinked identity', () async {
    final gateway = _ReadGateway();
    final dynamic repository = ConvertRepository(gateway);
    dynamic result;
    try {
      result = await repository.get(
        congregationId: null,
        convertId: _legacyConvertId,
      );
    } on NoSuchMethodError {
      // A missing bounded detail read is the expected RED before implementation.
    }

    expect(result, isNotNull);
    expect(result.name, 'Pessoa legada sem congregação');
    expect(gateway.calls.single.rpc, 'ministry_get_convert');
    expect(gateway.calls.single.parameters, {
      'congregation_id': null,
      'convert_id': _legacyConvertId,
    });
  });
}
