import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/features/photos/photo_repository.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/converts/convert_save_controller.dart';

import 'save_test.dart' show TestGateway;

class Photos implements PhotoRepository {
  int uploads = 0;
  bool fail = false;
  VoidCallback? beforeReturn;
  @override
  Future<PhotoAsset> upload(Uint8List bytes) async {
    uploads++;
    if (fail) throw const DataFailure('unavailable');
    beforeReturn?.call();
    return const PhotoAsset(id: 'asset', path: 'owner/asset.jpg');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef VoidCallback = void Function();
ConvertDraft photoDraft({bool remove = false}) => ConvertDraft(
  name: 'Pessoa',
  landmark: 'Praça',
  gender: Gender.female,
  conversionDate: DateOnly(2026, 1, 1),
  worshipType: '01 - Oração',
  photoBytes: remove ? null : Uint8List.fromList([1, 2, 3]),
  removePhoto: remove,
);
void main() {
  test('failed upload never mutates convert; attach retry reuses asset and operation', () async {
    final gateway = TestGateway();
    final photos = Photos()..fail = true;
    final saver = ConvertSaveController(
      gateway: gateway,
      photos: photos,
      convertId: 'existing',
    );
    await expectLater(saver.save(photoDraft()), throwsA(isA<DataFailure>()));
    expect(gateway.calls, isEmpty);
    photos.fail = false;
    await expectLater(saver.save(photoDraft()), throwsA(isA<DataFailure>()));
    gateway.fail = false;
    expect(await saver.save(photoDraft()), 'record');
    expect(photos.uploads, 2);
    expect(gateway.calls[0], gateway.calls[1]);
    expect(
      gateway.calls.singleWhere(
        (c) => identical(c, gateway.calls.first),
      )['payload'],
      containsPair('photo_asset_id', 'asset'),
    );
  });
  test(
    'invalidation after upload discards result before convert command',
    () async {
      final gateway = TestGateway();
      final photos = Photos()..beforeReturn = gateway.boundary.invalidate;
      final saver = ConvertSaveController(gateway: gateway, photos: photos);
      await expectLater(
        saver.save(photoDraft()),
        throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
      );
      expect(gateway.calls, isEmpty);
    },
  );
  test(
    'removal is only an authorized save payload and never uploads',
    () async {
      final gateway = TestGateway()..fail = false;
      final photos = Photos();
      final saver = ConvertSaveController(
        gateway: gateway,
        photos: photos,
        convertId: 'existing',
      );
      expect(gateway.calls, isEmpty);
      await saver.save(photoDraft(remove: true));
      expect(photos.uploads, 0);
      expect(
        gateway.calls.single['payload'],
        containsPair('photo_asset_id', null),
      );
      expect(gateway.calls.single['command'], 'edit_convert');
    },
  );
}
