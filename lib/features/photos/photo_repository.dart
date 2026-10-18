import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import 'photo_processor.dart';

class PhotoAsset {
  const PhotoAsset({required this.id, required this.path});
  final String id;
  final String path;
  void validate() {
    validateUuid(id);
    final parts = path.split('/');
    if (parts.length != 2 || parts[1] != '$id.jpg') {
      throw const DataFailure('invalid_response');
    }
    validateUuid(parts.first);
  }
}

/// No byte or URL cache. The UI must clear memory images on boundary invalidation.
class PhotoRepository {
  PhotoRepository(this.gateway, {this.processor = processPhoto});
  final SupabaseGateway gateway;
  final Future<Uint8List> Function(Uint8List) processor;

  Future<T> _network<T>(String token, Future<T> Function() request) async {
    gateway.ensureCurrent(token);
    try {
      final value = await request().timeout(gateway.requestTimeout);
      gateway.ensureCurrent(token);
      return value;
    } catch (error) {
      gateway.ensureCurrent(token);
      if (error is DataFailure) rethrow;
      if (error is TimeoutException) throw const DataFailure('unavailable');
      if (error is StorageException) {
        if ({'401', '403', '404'}.contains(error.statusCode)) {
          throw const DataFailure('permission');
        }
        if ({'400', '409', '413', '415'}.contains(error.statusCode)) {
          throw const DataFailure('invalid');
        }
        if ({'502', '503', '504'}.contains(error.statusCode)) {
          throw const DataFailure('unavailable');
        }
      }
      throw const DataFailure('backend');
    }
  }

  Future<PhotoAsset> upload(Uint8List bytes) async {
    final token = gateway.context;
    final owner = gateway.client.auth.currentUser?.id;
    if (owner == null) throw const DataFailure('permission');
    final Uint8List encoded;
    try {
      encoded = await processor(Uint8List.fromList(bytes));
    } catch (_) {
      gateway.ensureCurrent(token);
      rethrow;
    }
    gateway.ensureCurrent(token);
    if (encoded.isEmpty || encoded.length > 1048576) {
      throw const DataFailure('invalid');
    }
    final draft = await gateway.command(
      'create_photo_draft',
      const Uuid().v4(),
      {},
    );
    gateway.ensureCurrent(token);
    if (draft.status != MutationStatus.applied || draft.value == null) {
      throw DataFailure(draft.errorCode ?? 'invalid_response');
    }
    final asset = PhotoAsset(
      id: draft.value!,
      path: '$owner/${draft.value}.jpg',
    );
    asset.validate();
    await _network(
      token,
      () => gateway.client.storage
          .from('convert-photos')
          .uploadBinary(
            asset.path,
            encoded,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '0',
              upsert: false,
            ),
            retryAttempts: 0,
          ),
    );
    return asset;
  }

  /// Resolve a convert's asset ID through current SQL RLS, including other uploaders.
  Future<PhotoAsset> get(String id) async {
    validateUuid(id);
    final token = gateway.context;
    final rows = await gateway.read(
      'photo_assets',
      context: token,
      equals: {'id': id},
    );
    gateway.ensureCurrent(token);
    if (rows.isEmpty) throw const DataFailure('permission');
    if (rows.length != 1 ||
        rows.single['id'] != id ||
        rows.single['path'] is! String) {
      throw const DataFailure('invalid_response');
    }
    final asset = PhotoAsset(id: id, path: rows.single['path'] as String);
    asset.validate();
    return asset;
  }

  Future<Uint8List> download(PhotoAsset asset) async {
    asset.validate();
    final token = gateway.context;
    final bytes = await _network(
      token,
      () => gateway.client.storage
          .from('convert-photos')
          .download(asset.path, cacheNonce: const Uuid().v4()),
    );
    if (bytes.length < 4 ||
        bytes.length > 1048576 ||
        bytes[0] != 255 ||
        bytes[1] != 216) {
      throw const DataFailure('invalid_response');
    }
    return bytes;
  }
}
