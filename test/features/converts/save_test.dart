import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/features/photos/photo_repository.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/converts/convert_save_controller.dart';

const _congregationId = 'b0000000-0000-4000-8000-000000000001';

class TestGateway implements ConvertCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  final calls = <Map<String, Object?>>[];
  final typedCalls = <Map<String, Object?>>[];
  bool fail = true;
  @override
  Future<MutationResult<PersonRegistrationResult>> saveConvert(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    final frozen = Map<String, Object?>.from(payload);
    calls.add({
      'command': command,
      'operationId': operationId,
      'payload': frozen,
    });
    typedCalls.add(calls.last);
    final expectedRevision = payload['expected_revision'] as int?;
    final expectedPersonRevision = payload['expected_person_revision'] as int?;
    return fail
        ? MutationResult.rejected(
            operationId: operationId,
            errorCode: 'unavailable',
          )
        : MutationResult.applied(
            operationId: operationId,
            value: PersonRegistrationResult(
              personId: 'person',
              convertId: payload['id'] as String? ?? 'record',
              personRevision: expectedPersonRevision ?? 1,
              convertRevision: (expectedRevision ?? 0) + 1,
            ),
          );
  }

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    calls.add({
      'command': command,
      'operationId': operationId,
      'payload': Map.of(payload),
    });
    return fail
        ? MutationResult.rejected(
            operationId: operationId,
            errorCode: 'unavailable',
          )
        : MutationResult.applied(operationId: operationId, value: 'record');
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
}

class NoPhotos implements PhotoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _legacyLongName = List.filled(244, 'A').join();

ConvertDraft draft({String name = 'Pessoa', String landmark = 'Praça'}) =>
    ConvertDraft(
      name: name,
      landmark: landmark,
      gender: Gender.male,
      conversionDate: DateOnly(2026, 1, 1),
      worshipType: '01 - Oração',
      congregationId: _congregationId,
      age: 0,
    );
void main() {
  test(
    'convert registration nests canonical identity apart from convert fields',
    () async {
      final gateway = TestGateway()..fail = false;
      final saver = ConvertSaveController(gateway: gateway, photos: NoPhotos());

      await saver.save(draft());

      final payload = gateway.calls.single['payload'] as Map<String, Object?>;
      expect(payload['person'], {
        'name': 'Pessoa',
        'phone': null,
        'birth_date': null,
        'address': {
          'street': null,
          'district': null,
          'city': null,
          'postal_code': null,
          'state_code': null,
        },
      });
      expect(payload['convert'], {
        'landmark': 'Praça',
        'gender': 'male',
        'conversion_date': '2026-01-01',
        'worship_type': '01 - Oração',
        'age': 0,
        'photo_asset_id': null,
      });
      expect(payload, isNot(contains('name')));
      expect(payload, isNot(contains('landmark')));
      expect(gateway.typedCalls, hasLength(1));
      expect(gateway.typedCalls.single['command'], 'create_convert');
    },
  );

  test('save uses editable payload and retries identical operation after rejection', () async {
    final gateway = TestGateway();
    final saver = ConvertSaveController(gateway: gateway, photos: NoPhotos());
    await expectLater(saver.save(draft()), throwsA(isA<DataFailure>()));
    gateway.fail = false;
    expect(await saver.save(draft()), 'record');
    expect(gateway.calls.length, 2);
    expect(gateway.calls[0], gateway.calls[1]);
    expect(((gateway.calls[0]['payload'] as Map)['convert'] as Map)['age'], 0);
    expect(
      (gateway.calls[0]['payload'] as Map).containsKey('visit_count'),
      false,
    );
    await saver.save(draft(name: 'Outra'));
    expect(
      gateway.calls.last['operationId'],
      isNot(gateway.calls.first['operationId']),
    );
  });

  test('unrelated convert edit carries the inherited name and independent revisions', () async {
    final initial = ConvertRecord(
      id: 'd0000000-0000-4000-8000-000000000001',
      internalId: 'd0000000-0000-4000-8000-000000000001',
      name: _legacyLongName,
      landmark: 'Praça antiga',
      gender: Gender.male,
      conversionDate: DateOnly(2026, 1, 1),
      worshipType: '01 - Oração',
      congregationId: _congregationId,
      personId: 'e0000000-0000-4000-8000-000000000001',
      convertRevision: 3,
      personRevision: 7,
      personIdentity: CanonicalPersonIdentity(name: _legacyLongName),
    );
    final gateway = TestGateway()..fail = false;
    final saver = ConvertSaveController(
      gateway: gateway,
      photos: NoPhotos(),
      initial: initial,
    );

    await saver.save(draft(name: _legacyLongName, landmark: 'Praça nova'));

    final call = gateway.calls.single;
    final payload = call['payload'] as Map<String, Object?>;
    expect(call['command'], 'edit_convert');
    expect(payload['id'], initial.id);
    expect(payload['expected_revision'], 3);
    expect(payload['expected_person_revision'], 7);
    expect((payload['person'] as Map)['name'], _legacyLongName);
    expect((payload['convert'] as Map)['landmark'], 'Praça nova');
  });
}
