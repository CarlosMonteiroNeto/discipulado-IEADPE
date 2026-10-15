import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ieadpe_converts/features/photos/photo_processor.dart';

void main() {
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
