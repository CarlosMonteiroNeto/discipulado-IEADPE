import 'dart:math' as math;

const int maxProfilePhotoPixels = 24000000;

bool isSupportedProfilePhotoDimensions(int width, int height) =>
    width > 0 && height > 0 && width <= maxProfilePhotoPixels ~/ height;

/// A square crop in the source image's orientation-corrected coordinate space.
///
/// [left] and [top] are normalized by the corresponding source dimension;
/// [size] is normalized by the smaller source dimension. Pixel bounds therefore
/// need the source dimensions and are checked by [toPixels].
final class NormalizedPhotoCrop {
  NormalizedPhotoCrop({
    required this.left,
    required this.top,
    required this.size,
  }) {
    if (!left.isFinite ||
        !top.isFinite ||
        !size.isFinite ||
        left < 0 ||
        top < 0 ||
        left > 1 ||
        top > 1 ||
        size <= 0 ||
        size > 1) {
      throw ArgumentError('Invalid normalized photo crop.');
    }
  }

  final double left;
  final double top;
  final double size;

  factory NormalizedPhotoCrop.centered({
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Photo dimensions must be positive.');
    }
    final side = math.min(width, height);
    return NormalizedPhotoCrop(
      left: (width - side) / (2 * width),
      top: (height - side) / (2 * height),
      size: 1,
    );
  }

  PhotoCropRect toPixels({required int width, required int height}) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Photo dimensions must be positive.');
    }
    final side = (size * math.min(width, height)).round();
    final x = (left * width).round();
    final y = (top * height).round();
    if (side < 1 || x < 0 || y < 0 || x + side > width || y + side > height) {
      throw ArgumentError('Photo crop exceeds oriented image bounds.');
    }
    return PhotoCropRect(left: x, top: y, side: side);
  }

  @override
  bool operator ==(Object other) =>
      other is NormalizedPhotoCrop &&
      other.left == left &&
      other.top == top &&
      other.size == size;

  @override
  int get hashCode => Object.hash(left, top, size);
}

final class PhotoCropRect {
  const PhotoCropRect({
    required this.left,
    required this.top,
    required this.side,
  });

  final int left;
  final int top;
  final int side;

  @override
  bool operator ==(Object other) =>
      other is PhotoCropRect &&
      other.left == left &&
      other.top == top &&
      other.side == side;

  @override
  int get hashCode => Object.hash(left, top, side);
}
