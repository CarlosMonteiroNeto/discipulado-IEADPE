import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import '../../data/supabase_gateway.dart';

/// Processing is isolated on native targets; callers check context after await.
Future<Uint8List> processPhoto(Uint8List bytes) => compute(_encodePhoto, bytes);

Uint8List _encodePhoto(Uint8List bytes) {
  try {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const DataFailure('invalid');
    }
    final decoder = image.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > 24000000) {
      throw const DataFailure('invalid');
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) throw const DataFailure('invalid');
    final square = image.copyResizeCropSquare(
      image.bakeOrientation(decoded),
      size: 192,
      interpolation: image.Interpolation.linear,
    );
    // Copy pixels to discard EXIF/GPS and other source metadata.
    final clean = image.Image(width: 192, height: 192, numChannels: 3);
    image.fill(clean, color: image.ColorRgb8(255, 255, 255));
    image.compositeImage(clean, square);
    final result = Uint8List.fromList(image.encodeJpg(clean, quality: 90));
    if (result.length > 1048576) throw const DataFailure('invalid');
    return result;
  } on DataFailure {
    rethrow;
  } catch (_) {
    throw const DataFailure('invalid');
  }
}
