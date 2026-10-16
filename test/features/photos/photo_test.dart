import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
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
  test('independent PNG transparency composites onto white', () async {
    final output = await processPhoto(
      await File('test/features/photos/fixtures/transparent.png').readAsBytes(),
    );
    final decoded = image.decodeJpg(output)!;
    expect(decoded.getPixel(0, 0).r, greaterThan(245));
    expect(decoded.getPixel(0, 0).g, greaterThan(245));
    expect(decoded.getPixel(96, 96).r, greaterThan(245));
    expect(decoded.getPixel(96, 96).g, inInclusiveRange(115, 140));
  });
  test('center crop emits a 192 square JPEG under the object limit', () async {
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
    expect([decoded.width, decoded.height], [192, 192]);
    expect(decoded.getPixel(0, 96).g, greaterThan(240));
    expect(bytes.length, lessThanOrEqualTo(1048576));
  });
}
