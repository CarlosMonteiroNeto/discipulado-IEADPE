import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import '../../data/supabase_gateway.dart';
import 'photo_crop.dart';

const int _maxInputBytes = 20 * 1024 * 1024;
const int _outputSize = 512;
const int _targetBytes = 102400;
const int _maxOutputBytes = 204800;
const List<int> _qualitySteps = [90, 80, 70, 60, 55];

/// Applies orientation, one confirmed square crop, then one 512px resize.
/// Omitting [crop] keeps the historical centered-crop behavior.
Future<Uint8List> processPhoto(Uint8List bytes, {NormalizedPhotoCrop? crop}) =>
    compute(_encodePhoto, <String, Object?>{
      'bytes': Uint8List.fromList(bytes),
      'left': crop?.left,
      'top': crop?.top,
      'size': crop?.size,
    });

Uint8List _encodePhoto(Map<String, Object?> request) {
  try {
    final bytes = request['bytes']! as Uint8List;
    if (bytes.isEmpty || bytes.length > _maxInputBytes) {
      throw const DataFailure('invalid');
    }
    final decoder = image.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null ||
        !isSupportedProfilePhotoDimensions(info.width, info.height)) {
      throw const DataFailure('invalid');
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) throw const DataFailure('invalid');
    final oriented = image.bakeOrientation(decoded);
    if (!isSupportedProfilePhotoDimensions(oriented.width, oriented.height)) {
      throw const DataFailure('invalid');
    }

    final hasCrop = request['left'] != null;
    final selectedCrop = hasCrop
        ? NormalizedPhotoCrop(
            left: request['left']! as double,
            top: request['top']! as double,
            size: request['size']! as double,
          )
        : NormalizedPhotoCrop.centered(
            width: oriented.width,
            height: oriented.height,
          );
    final rect = selectedCrop.toPixels(
      width: oriented.width,
      height: oriented.height,
    );
    final region = image.copyCrop(
      oriented,
      x: rect.left,
      y: rect.top,
      width: rect.side,
      height: rect.side,
    );
    final resized = image.copyResize(
      region,
      width: _outputSize,
      height: _outputSize,
      interpolation: image.Interpolation.linear,
    );

    // Rebuild pixels to drop EXIF/GPS and composite transparency on white.
    final clean = image.Image(
      width: _outputSize,
      height: _outputSize,
      numChannels: 3,
    );
    image.fill(clean, color: image.ColorRgb8(255, 255, 255));
    image.compositeImage(clean, resized);

    Uint8List? last;
    for (final quality in _qualitySteps) {
      last = Uint8List.fromList(image.encodeJpg(clean, quality: quality));
      if (last.length <= _targetBytes) return last;
    }
    if (last == null || last.length > _maxOutputBytes) {
      throw const DataFailure('invalid');
    }
    return last;
  } on DataFailure {
    rethrow;
  } on ArgumentError {
    throw const DataFailure('invalid');
  } catch (_) {
    throw const DataFailure('invalid');
  }
}
