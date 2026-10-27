import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/photos/photo_crop.dart';

void main() {
  test('normalized crop resolves against the oriented source dimensions', () {
    final landscape = NormalizedPhotoCrop(left: .5, top: 0, size: 1);
    expect(
      landscape.toPixels(width: 400, height: 200),
      const PhotoCropRect(left: 200, top: 0, side: 200),
    );

    final portrait = NormalizedPhotoCrop(left: 0, top: .5, size: 1);
    expect(
      portrait.toPixels(width: 200, height: 400),
      const PhotoCropRect(left: 0, top: 200, side: 200),
    );
  });

  test('pixel conversion rounds coordinates and side deterministically', () {
    final crop = NormalizedPhotoCrop(left: .1, top: .1, size: .333);
    expect(
      crop.toPixels(width: 403, height: 200),
      const PhotoCropRect(left: 40, top: 20, side: 67),
    );
  });

  test('rejects invalid normalized values and oriented pixel overflow', () {
    expect(
      () => NormalizedPhotoCrop(left: double.nan, top: 0, size: .5),
      throwsArgumentError,
    );
    expect(
      () => NormalizedPhotoCrop(left: 0, top: 0, size: 0),
      throwsArgumentError,
    );
    expect(
      () => NormalizedPhotoCrop(
        left: .51,
        top: 0,
        size: 1,
      ).toPixels(width: 400, height: 200),
      throwsArgumentError,
    );
  });

  test('centered crop remains square for a rectangular oriented image', () {
    expect(
      NormalizedPhotoCrop.centered(
        width: 400,
        height: 200,
      ).toPixels(width: 400, height: 200),
      const PhotoCropRect(left: 100, top: 0, side: 200),
    );
  });
}
