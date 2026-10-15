import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/features/photos/photo_repository.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/converts/convert_save_controller.dart';

class TestGateway implements Gateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  final calls = <Map<String, Object?>>[];
  bool fail = true;
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

ConvertDraft draft({String name = 'Pessoa'}) => ConvertDraft(
  name: name,
  landmark: 'Praça',
  gender: Gender.male,
  conversionDate: DateOnly(2026, 1, 1),
  worshipType: '01 - Oração',
  age: 0,
);
void main() {
  test('save uses editable payload and retries identical operation after rejection', () async {
    final gateway = TestGateway();
    final saver = ConvertSaveController(gateway: gateway, photos: NoPhotos());
    await expectLater(saver.save(draft()), throwsA(isA<DataFailure>()));
    gateway.fail = false;
    expect(await saver.save(draft()), 'record');
    expect(gateway.calls.length, 2);
    expect(gateway.calls[0], gateway.calls[1]);
    expect((gateway.calls[0]['payload'] as Map)['age'], 0);
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
}
