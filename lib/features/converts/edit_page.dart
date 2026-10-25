import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/convert_repository.dart';
import '../../domain/models.dart';
import '../photos/photo_repository.dart';
import 'convert_form.dart';
import 'register_page.dart';

class EditPage extends StatelessWidget {
  const EditPage({
    super.key,
    required this.initial,
    required this.converts,
    required this.photos,
    this.congregations = const [],
    this.onCancel,
    this.onSaved,
    this.pickPhoto = pickConvertPhoto,
    required this.scope,
    this.revalidatePhotoAuthority,
  });
  final ConvertRecord initial;
  final ConvertRepository converts;
  final PhotoRepository photos;
  final List<Congregation> congregations;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onSaved;
  final Future<Uint8List?> Function() pickPhoto;
  final AccessScope scope;
  final Future<bool> Function(String? congregationId)? revalidatePhotoAuthority;
  @override
  Widget build(BuildContext context) => RegisterPage(
    initial: initial,
    converts: converts,
    photos: photos,
    congregations: congregations,
    onCancel: onCancel,
    onSaved: onSaved,
    pickPhoto: pickPhoto,
    scope: scope,
    revalidatePhotoAuthority: revalidatePhotoAuthority,
  );
}
