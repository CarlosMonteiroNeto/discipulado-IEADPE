import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/features/photos/photo_repository.dart';
import 'package:ieadpe_converts/features/photos/photo_crop.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/converts/convert_save_controller.dart';

import 'save_test.dart' show TestGateway;

class Photos implements PhotoRepository {
  int uploads = 0;
  NormalizedPhotoCrop? lastCrop;
  bool fail = false;
  VoidCallback? beforeReturn;
  @override
  Future<PhotoAsset> upload(
    Uint8List bytes, {
    NormalizedPhotoCrop? crop,
  }) async {
    uploads++;
    lastCrop = crop;
    if (fail) throw const DataFailure('unavailable');
    beforeReturn?.call();
    return const PhotoAsset(id: 'asset', path: 'owner/asset.jpg');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef VoidCallback = void Function();
ConvertDraft photoDraft({
  bool remove = false,
  bool upload = true,
  NormalizedPhotoCrop? crop,
}) => ConvertDraft(
  name: 'Pessoa',
  landmark: 'Praça',
  gender: Gender.female,
  conversionDate: DateOnly(2026, 1, 1),
  worshipType: '01 - Oração',
  congregationId: 'congregation',
  photoBytes: remove || !upload ? null : Uint8List.fromList([1, 2, 3]),
  photoCrop: crop,
  removePhoto: remove,
);
ConvertRecord photoRecord({String? photoAssetId = 'attached-asset'}) =>
    ConvertRecord(
      id: 'existing',
      internalId: 'existing',
      name: 'Pessoa',
      landmark: 'Praça',
      gender: Gender.female,
      conversionDate: DateOnly(2026, 1, 1),
      worshipType: '01 - Oração',
      congregationId: 'congregation',
      photoAssetId: photoAssetId,
      personId: 'person',
      personRevision: 1,
    );
void main() {
  test('save forwards the confirmed crop to the photo repository', () async {
    final gateway = TestGateway()..fail = false;
    final photos = Photos();
    final crop = NormalizedPhotoCrop(left: .5, top: 0, size: 1);
    final saver = ConvertSaveController(gateway: gateway, photos: photos);

    await saver.save(photoDraft(crop: crop));

    expect(photos.lastCrop, crop);
  });
  test('failed upload never mutates convert; attach retry reuses asset and operation', () async {
    final gateway = TestGateway();
    final photos = Photos()..fail = true;
    final saver = ConvertSaveController(
      gateway: gateway,
      photos: photos,
      initial: photoRecord(photoAssetId: 'previous-asset'),
    );
    await expectLater(saver.save(photoDraft()), throwsA(isA<DataFailure>()));
    expect(gateway.calls, isEmpty);
    photos.fail = false;
    await expectLater(saver.save(photoDraft()), throwsA(isA<DataFailure>()));
    gateway.fail = false;
    expect(await saver.save(photoDraft()), 'existing');
    expect(photos.uploads, 2);
    expect(gateway.calls[0], gateway.calls[1]);
    expect(
      ((gateway.calls.first['payload'] as Map)['convert']
          as Map)['photo_asset_id'],
      'asset',
    );
  });
  test(
    'an edit preserves its attached photo when the form leaves it unchanged',
    () async {
      final gateway = TestGateway()..fail = false;
      final photos = Photos();
      final saver = ConvertSaveController(
        gateway: gateway,
        photos: photos,
        initial: photoRecord(),
      );

      await saver.save(photoDraft(upload: false));

      expect(photos.uploads, 0);
      final convert =
          (gateway.calls.single['payload'] as Map)['convert'] as Map;
      expect(convert['photo_asset_id'], 'attached-asset');
    },
  );
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
        initial: photoRecord(),
      );
      expect(gateway.calls, isEmpty);
      await saver.save(photoDraft(remove: true));
      expect(photos.uploads, 0);
      expect(
        ((gateway.calls.single['payload'] as Map)['convert']
            as Map)['photo_asset_id'],
        null,
      );
      expect(gateway.calls.single['command'], 'edit_convert');
    },
  );
}
