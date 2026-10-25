import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/photos/photo_crop.dart';
import 'package:ieadpe_converts/features/photos/photo_processor.dart';

void main() {
  test(
    'independent Pillow EXIF orientation and private metadata are normalized',
    () async {
      final output = await processPhoto(
        await File('test/features/photos/fixtures/orientation6.jpg')
            .readAsBytes(),
      );
      final decoded = image.decodeJpg(output)!;
      expect([decoded.width, decoded.height], [512, 512]);
      final upperLeft = decoded.getPixel(30, 30);
      expect(upperLeft.b, greaterThan(240));
      expect(upperLeft.r, lessThan(15));
      expect(
        latin1.decode(output).contains('Synthetic private marker'),
        isFalse,
      );
      expect(decoded.exif.imageIfd.hasOrientation, isFalse);
    },
  );
  test('selected crop coordinates apply after EXIF orientation 6', () async {
    final output = await processPhoto(
      await File('test/features/photos/fixtures/orientation6.jpg')
          .readAsBytes(),
      crop: NormalizedPhotoCrop(left: 0, top: 0, size: .5),
    );
    final decoded = image.decodeJpg(output)!;
    expect([decoded.width, decoded.height], [512, 512]);
    final selectedCenter = decoded.getPixel(256, 256);
    expect(selectedCenter.b, greaterThan(220));
    expect(selectedCenter.r, lessThan(40));
    expect(decoded.exif.imageIfd.hasOrientation, isFalse);
  });
  test('independent PNG transparency composites onto white', () async {
    final output = await processPhoto(
      await File('test/features/photos/fixtures/transparent.png').readAsBytes(),
    );
    final decoded = image.decodeJpg(output)!;
    expect(decoded.getPixel(0, 0).r, greaterThan(245));
    expect(decoded.getPixel(0, 0).g, greaterThan(245));
    expect(decoded.getPixel(256, 256).r, greaterThan(245));
    expect(decoded.getPixel(256, 256).g, inInclusiveRange(115, 140));
  });
  test('center crop emits a standardized 512 square JPEG', () async {
    final source = image.Image(width: 400, height: 200);
    image.fill(source, color: image.ColorRgb8(255, 0, 0));
    image.fillRect(
      source,
      x1: 100,
      y1: 0,
      x2: 299,
      y2: 199,
      color: image.ColorRgb8(0, 255, 0),
    );
    final bytes = await processPhoto(
      Uint8List.fromList(image.encodePng(source)),
    );
    expect(bytes.take(2), [255, 216]);
    final decoded = image.decodeJpg(bytes)!;
    expect([decoded.width, decoded.height], [512, 512]);
    expect(decoded.getPixel(0, 256).g, greaterThan(240));
    expect(bytes.length, lessThanOrEqualTo(204800));
  });

  test('confirmed_crop_is_applied_once', () async {
    final source = image.Image(width: 400, height: 200);
    image.fill(source, color: image.ColorRgb8(240, 20, 20));
    image.fillRect(
      source,
      x1: 200,
      y1: 0,
      x2: 399,
      y2: 199,
      color: image.ColorRgb8(20, 40, 240),
    );

    final bytes = await processPhoto(
      Uint8List.fromList(image.encodePng(source)),
      crop: NormalizedPhotoCrop(left: .5, top: 0, size: 1),
    );
    final decoded = image.decodeJpg(bytes)!;

    expect([decoded.width, decoded.height], [512, 512]);
    expect(decoded.getPixel(256, 256).b, greaterThan(220));
    expect(decoded.getPixel(256, 256).r, lessThan(40));
    expect(latin1.decode(bytes).contains('eXIf'), isFalse);
    expect(bytes.length, lessThanOrEqualTo(204800));
  });

  test('portrait crop preserves the selected lower face region', () async {
    final source = image.Image(width: 200, height: 400);
    image.fill(source, color: image.ColorRgb8(240, 20, 20));
    image.fillRect(
      source,
      x1: 0,
      y1: 200,
      x2: 199,
      y2: 399,
      color: image.ColorRgb8(20, 40, 240),
    );

    final bytes = await processPhoto(
      Uint8List.fromList(image.encodePng(source)),
      crop: NormalizedPhotoCrop(left: 0, top: .5, size: 1),
    );
    final decoded = image.decodeJpg(bytes)!;
    expect([decoded.width, decoded.height], [512, 512]);
    expect(decoded.getPixel(256, 256).b, greaterThan(220));
    expect(decoded.getPixel(256, 256).r, lessThan(40));
  });

  test(
    'accepts the exact 20 MiB input boundary and rejects one byte over',
    () async {
      final sample = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 32, height: 32)),
      );
      final exact = Uint8List(20 * 1024 * 1024)
        ..setRange(0, sample.length, sample);
      final output = await processPhoto(exact);
      expect(
        [image.decodeJpg(output)!.width, image.decodeJpg(output)!.height],
        [512, 512],
      );

      await expectLater(
        processPhoto(Uint8List(20 * 1024 * 1024 + 1)),
        throwsA(
          isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
        ),
      );
    },
  );

  test(
    'invalid empty, corrupt and crop-overflow inputs are rejected',
    () async {
      final source = Uint8List.fromList(
        image.encodePng(image.Image(width: 400, height: 200)),
      );
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
      ]) {
        await expectLater(
          processPhoto(bytes),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
          ),
        );
      }
      await expectLater(
        processPhoto(
          source,
          crop: NormalizedPhotoCrop(left: .51, top: 0, size: 1),
        ),
        throwsA(
          isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
        ),
      );
    },
  );

  test(
    'tiny valid sources are resized to the required square output',
    () async {
      final tiny = image.Image(width: 1, height: 1);
      image.fill(tiny, color: image.ColorRgb8(50, 120, 200));
      final output = await processPhoto(
        Uint8List.fromList(image.encodePng(tiny)),
      );
      final decoded = image.decodeJpg(output)!;
      expect([decoded.width, decoded.height], [512, 512]);
      expect(decoded.getPixel(256, 256).b, greaterThan(180));
    },
  );

  test(
    '24 megapixel source boundary is inclusive and larger dimensions fail',
    () {
      expect(isSupportedProfilePhotoDimensions(6000, 4000), isTrue);
      expect(isSupportedProfilePhotoDimensions(6001, 4000), isFalse);
      expect(isSupportedProfilePhotoDimensions(0, 4000), isFalse);
    },
  );
}
