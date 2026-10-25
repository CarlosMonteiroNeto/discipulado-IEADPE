import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/photos/photo_repository.dart';

import '../../data/repositories_test.dart' as fixture;

Future<void> signIn(
  SupabaseGateway gateway,
) => gateway.client.auth.setInitialSession(
  jsonEncode({
    'access_token':
        'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature',
    'token_type': 'bearer',
    'user': {
      'id': fixture.id(99),
      'aud': 'authenticated',
      'created_at': '2026-10-15T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    },
  }),
);
Uint8List sample() =>
    Uint8List.fromList(image.encodePng(image.Image(width: 200, height: 300)));
void main() {
  test(
    'failed stale processing is discarded before publishing a validation error',
    () async {
      final gateway = await fixture.fixture((r) => fixture.respond(r, {}));
      await signIn(gateway);
      final processing = Completer<Uint8List>();
      final pending = PhotoRepository(
        gateway,
        processor: (_) => processing.future,
      ).upload(sample());
      final check = expectLater(
        pending,
        throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
      );
      gateway.boundary.invalidate();
      processing.completeError(const DataFailure('invalid'));
      await check;
    },
  );
  test('actual SDK sends draft then exact JPEG INSERT without upsert', () async {
    final paths = <String>[];
    final gateway = await fixture.fixture((r) async {
      paths.add(r.uri.path);
      if (r.uri.path.endsWith('ieadpe_create_photo_draft')) {
        final envelope = jsonDecode(await utf8.decoder.bind(r).join()) as Map;
        expect(envelope['payload'], isEmpty);
        expect(envelope['operation_id'], isA<String>());
        await fixture.respond(r, {'id': fixture.id(1)});
      } else {
        expect(r.method, 'POST');
        expect(r.headers.value('x-upsert'), 'false');
        final body = await r.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(utf8.decode(body, allowMalformed: true), contains('image/jpeg'));
        expect(
          utf8.decode(body, allowMalformed: true),
          contains('name="cacheControl"\r\n\r\n0'),
        );
        await fixture.respond(r, {
          'Key': 'convert-photos/${fixture.id(99)}/${fixture.id(1)}.jpg',
        });
      }
    });
    await signIn(gateway);
    final asset = await PhotoRepository(gateway).upload(sample());
    expect(asset.id, fixture.id(1));
    expect(asset.path, '${fixture.id(99)}/${fixture.id(1)}.jpg');
    expect(paths, [
      '/rest/v1/rpc/ieadpe_create_photo_draft',
      '/storage/v1/object/convert-photos/${fixture.id(99)}/${fixture.id(1)}.jpg',
    ]);
  });
  test(
    'Storage upload denial is reported as a photo-specific failure',
    () async {
      final gateway = await fixture.fixture((r) async {
        if (r.uri.path.endsWith('ieadpe_create_photo_draft')) {
          await fixture.respond(r, {'id': fixture.id(1)});
        } else {
          await r.drain<void>();
          await fixture.respond(r, {
            'statusCode': '403',
            'error': 'Unauthorized',
            'message': 'new row violates row-level security policy',
          }, 400);
        }
      });
      await signIn(gateway);
      await expectLater(
        PhotoRepository(gateway).upload(sample()),
        throwsA(
          isA<DataFailure>().having(
            (error) => error.code,
            'code',
            'photo_upload',
          ),
        ),
      );
    },
  );
  test('authenticated download discards completion after invalidation', () async {
    final received = Completer<void>();
    final release = Completer<void>();
    final gateway = await fixture.fixture((r) async {
      expect(r.headers.value('authorization'), startsWith('Bearer '));
      expect(
        r.uri.path,
        '/storage/v1/object/convert-photos/${fixture.id(99)}/${fixture.id(1)}.jpg',
      );
      received.complete();
      await release.future;
      r.response.add([255, 216, 255, 217]);
      await r.response.close();
    });
    await signIn(gateway);
    final result = PhotoRepository(gateway).download(
      PhotoAsset(
        id: fixture.id(1),
        path: '${fixture.id(99)}/${fixture.id(1)}.jpg',
      ),
    );
    final check = expectLater(
      result,
      throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
    );
    await received.future;
    gateway.boundary.invalidate();
    release.complete();
    await check;
  });
  test('invalidation during processing prevents draft creation', () async {
    var requests = 0;
    final gateway = await fixture.fixture((r) async {
      requests++;
      await fixture.respond(r, {});
    });
    await signIn(gateway);
    final processing = Completer<Uint8List>();
    final repository = PhotoRepository(
      gateway,
      processor: (_) => processing.future,
    );
    final pending = repository.upload(sample());
    final check = expectLater(
      pending,
      throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
    );
    gateway.boundary.invalidate();
    processing.complete(Uint8List.fromList([255, 216, 255, 217]));
    await check;
    expect(requests, 0);
  });
  test(
    'ambiguous failed upload never retries INSERT or mutates a convert',
    () async {
      final paths = <String>[];
      final gateway = await fixture.fixture((r) async {
        paths.add(r.uri.path);
        await r.drain<void>();
        if (r.uri.path.endsWith('ieadpe_create_photo_draft')) {
          await fixture.respond(r, {'id': fixture.id(1)});
        } else {
          await fixture.respond(r, {
            'statusCode': '503',
            'message': 'synthetic failure',
          }, 503);
        }
      });
      await signIn(gateway);
      await expectLater(
        PhotoRepository(gateway).upload(sample()),
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
      expect(paths, hasLength(2));
      expect(paths.last, contains('/storage/v1/object/'));
    },
  );
  test('asset lookup keeps legacy 192px JPEG downloads readable without a URL cache', () async {
    final legacy192 = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 192, height: 192)),
    );
    final gateway = await fixture.fixture((r) async {
      if (r.uri.path == '/rest/v1/photo_assets') {
        expect(r.uri.queryParameters['id'], 'eq.${fixture.id(1)}');
        await fixture.respond(r, [
          {
            'id': fixture.id(1),
            'path': '${fixture.id(88)}/${fixture.id(1)}.jpg',
          },
        ]);
      } else {
        expect(r.uri.queryParameters['cacheNonce'], isNotEmpty);
        r.response.add(legacy192);
        await r.response.close();
      }
    });
    await signIn(gateway);
    final repository = PhotoRepository(gateway);
    final asset = await repository.get(fixture.id(1));
    final downloaded = await repository.download(asset);
    expect(image.decodeJpg(downloaded)!.width, 192);
    expect(downloaded, legacy192);
  });
}
