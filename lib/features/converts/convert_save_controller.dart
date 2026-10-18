import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../photos/photo_repository.dart';
import 'convert_form.dart';

/// In-memory retry owner. Clear synchronously and unmount its form on scope loss.
class ConvertSaveController {
  ConvertSaveController({
    required this.gateway,
    required this.photos,
    this.convertId,
  }) : _context = gateway.context;
  final String _context;
  final Gateway gateway;
  final PhotoRepository photos;
  final String? convertId;
  String? _signature, _operationId;
  Map<String, Object?>? _payload;
  bool _busy = false;
  int _generation = 0;
  void clear() {
    _generation++;
    _signature = null;
    _operationId = null;
    _payload = null;
  }

  Future<String> save(ConvertDraft draft) async {
    if (_generation != 0) throw const DataFailure('stale');
    if (_busy) throw const DataFailure('invalid');
    final token = _context;
    final generation = _generation;
    void check() {
      gateway.ensureCurrent(token);
      if (generation != _generation) throw const DataFailure('stale');
    }

    check();
    _busy = true;
    try {
      final fields = draft.payload();
      final signature = jsonEncode([
        fields,
        draft.removePhoto,
        draft.photoBytes == null ? null : base64Encode(draft.photoBytes!),
      ]);
      if (_signature != signature) {
        _signature = signature;
        _operationId = null;
        _payload = null;
      }
      if (_payload == null) {
        final payload = <String, Object?>{
          if (convertId != null) 'id': convertId,
          ...fields,
        };
        if (draft.photoBytes != null) {
          final asset = await photos.upload(draft.photoBytes!);
          check();
          payload['photo_asset_id'] = asset.id;
        } else if (draft.removePhoto) {
          payload['photo_asset_id'] = null;
        }
        check();
        _payload = Map.unmodifiable(payload);
        _operationId = const Uuid().v4();
      }
      check();
      final result = await gateway.command(
        convertId == null ? 'create_convert' : 'edit_convert',
        _operationId!,
        _payload!,
      );
      check();
      if (result.status != MutationStatus.applied || result.value == null) {
        throw DataFailure(result.errorCode ?? 'invalid_response');
      }
      final id = result.value!;
      _signature = null;
      _operationId = null;
      _payload = null;
      return id;
    } finally {
      _busy = false;
    }
  }
}
