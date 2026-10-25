import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/supabase_gateway.dart';

const int _maximumPhotoBytes = 20 * 1024 * 1024;

/// Opens an explicit source chooser; the camera is never opened implicitly.
Future<ImageSource?> chooseProfilePhotoSource(BuildContext context) =>
    showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto com a câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

/// Acquires original bytes for the confirmed crop flow, without resizing them.
Future<Uint8List?> pickProfilePhoto(ImageSource source) async {
  final picker = ImagePicker();
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final lost = await picker.retrieveLostData();
      if (!lost.isEmpty) {
        if (lost.exception != null) throw lost.exception!;
        final file = lost.files?.lastOrNull ?? lost.file;
        if (file != null) return await _readBounded(file);
      }
    }
    final file = await picker.pickImage(source: source);
    if (file == null) return null;
    return await _readBounded(file);
  } on DataFailure {
    rethrow;
  } on PlatformException {
    throw const DataFailure('unavailable');
  } catch (_) {
    throw const DataFailure('unavailable');
  }
}

Future<Uint8List> _readBounded(XFile file) async {
  final length = await file.length();
  if (length <= 0 || length > _maximumPhotoBytes) {
    throw const DataFailure('invalid');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > _maximumPhotoBytes) {
    throw const DataFailure('invalid');
  }
  return bytes;
}
