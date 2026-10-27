import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';
import '../../domain/uuid_shape.dart';
import 'intake_models.dart';

const publicIntakeMaxRequestBytes = 16 * 1024;
const _catalogRpc = 'ieadpe_public_congregations';
const _intakePath = '/functions/v1/public-intake';

final class PublicCongregation {
  const PublicCongregation({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is PublicCongregation && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

enum PublicIntakeFailureCode {
  validation,
  conflict,
  rateLimited,
  unavailable,
  botCheckFailed,
  invalidResponse,
}

final class PublicIntakeFailure implements Exception {
  const PublicIntakeFailure(
    this.code, {
    this.outcomeUnknown = false,
    this.retryAfterSeconds,
  });

  final PublicIntakeFailureCode code;
  final bool outcomeUnknown;
  final int? retryAfterSeconds;

  @override
  String toString() => 'PublicIntakeFailure(${code.name})';
}

/// Public, bounded HTTP access to the names-only catalog and intake function.
/// It never uses the authenticated Supabase client or persists form data.
class PublicIntakeRepository {
  PublicIntakeRepository({
    required this.supabaseUrl,
    required this.publishableKey,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    final localHosts = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};
    if (supabaseUrl.host.isEmpty ||
        supabaseUrl.userInfo.isNotEmpty ||
        supabaseUrl.hasQuery ||
        supabaseUrl.hasFragment ||
        !{'', '/'}.contains(supabaseUrl.path) ||
        !(supabaseUrl.scheme == 'https' ||
            (supabaseUrl.scheme == 'http' &&
                localHosts.contains(supabaseUrl.host))) ||
        !RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(publishableKey)) {
      throw ArgumentError('Invalid public intake configuration');
    }
  }

  final Uri supabaseUrl;
  final String publishableKey;
  final Duration requestTimeout;
  final http.Client _client;
  final bool _ownsClient;

  Uri get _restCatalogUri => _endpoint('/rest/v1/rpc/$_catalogRpc');
  Uri get _submissionUri => _endpoint(_intakePath);

  Uri _endpoint(String path) => supabaseUrl.replace(path: path);

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Page<PublicCongregation>> listCongregations({
    String? cursor,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 100 || (cursor != null && !isUuidShape(cursor))) {
      throw const PublicIntakeFailure(PublicIntakeFailureCode.validation);
    }
    final response = await _post(_restCatalogUri, {
      'request': {'limit': limit, 'cursor': cursor},
    }, submission: false);
    if (response.statusCode != 200) {
      throw const PublicIntakeFailure(PublicIntakeFailureCode.unavailable);
    }
    try {
      final decoded = _decodeObject(response.body);
      if (!_hasExactKeys(decoded, {'items', 'next_cursor'}) ||
          decoded['items'] is! List) {
        throw const FormatException('Invalid public catalog response');
      }
      final rawItems = decoded['items'] as List;
      if (rawItems.length > limit) {
        throw const FormatException('Public catalog page exceeds its limit');
      }
      final items = <PublicCongregation>[];
      final ids = <String>{};
      for (final raw in rawItems) {
        if (raw is! Map) throw const FormatException('Invalid catalog item');
        final item = Map<String, Object?>.from(raw);
        if (!_hasExactKeys(item, {'id', 'name'}) ||
            item['id'] is! String ||
            item['name'] is! String) {
          throw const FormatException('Invalid catalog item');
        }
        final id = item['id'] as String;
        final name = item['name'] as String;
        if (!isUuidShape(id) ||
            name.trim().isEmpty ||
            name.length > 200 ||
            !ids.add(id)) {
          throw const FormatException('Invalid catalog item');
        }
        items.add(PublicCongregation(id: id, name: name));
      }
      final rawCursor = decoded['next_cursor'];
      if (rawCursor != null &&
          (rawCursor is! String ||
              !isUuidShape(rawCursor) ||
              items.length != limit ||
              rawCursor != items.last.id)) {
        throw const FormatException('Invalid public catalog cursor');
      }
      return Page(items: items, nextCursor: rawCursor as String?);
    } on FormatException {
      throw const PublicIntakeFailure(PublicIntakeFailureCode.invalidResponse);
    } on TypeError {
      throw const PublicIntakeFailure(PublicIntakeFailureCode.invalidResponse);
    }
  }

  /// Reads a bounded sequence once for the current form session.
  Future<List<PublicCongregation>> listAllCongregations() async {
    const maxPages = 50;
    final all = <PublicCongregation>[];
    final ids = <String>{};
    final cursors = <String>{};
    String? cursor;
    for (var pageNumber = 0; pageNumber < maxPages; pageNumber++) {
      final page = await listCongregations(cursor: cursor);
      for (final congregation in page.items) {
        if (!ids.add(congregation.id)) {
          throw const PublicIntakeFailure(
            PublicIntakeFailureCode.invalidResponse,
          );
        }
        all.add(congregation);
      }
      final next = page.nextCursor;
      if (next == null) return List.unmodifiable(all);
      if (!cursors.add(next) || next == cursor) {
        throw const PublicIntakeFailure(
          PublicIntakeFailureCode.invalidResponse,
        );
      }
      cursor = next;
    }
    throw const PublicIntakeFailure(PublicIntakeFailureCode.invalidResponse);
  }

  Future<void> submit({
    required String submissionId,
    required PublicIntakeDraft draft,
    required String turnstileToken,
  }) async {
    if (!isUuidShape(submissionId) ||
        turnstileToken.trim().isEmpty ||
        turnstileToken.length > 2048) {
      throw const PublicIntakeFailure(PublicIntakeFailureCode.validation);
    }
    final body = jsonEncode({
      'submission_id': submissionId,
      'turnstile_token': turnstileToken,
      'draft': draft.toJson(),
    });
    if (utf8.encode(body).length > publicIntakeMaxRequestBytes) {
      throw const PublicIntakeFailure(PublicIntakeFailureCode.validation);
    }
    final response = await _post(
      _submissionUri,
      jsonDecode(body) as Map<String, Object?>,
      submission: true,
    );
    if (response.statusCode == 202) {
      try {
        final decoded = _decodeObject(response.body);
        if (_hasExactKeys(decoded, {'status'}) &&
            decoded['status'] == 'received') {
          return;
        }
      } on FormatException {
        // An unparseable 202 may still represent a committed acceptance.
      }
      throw const PublicIntakeFailure(
        PublicIntakeFailureCode.invalidResponse,
        outcomeUnknown: true,
      );
    }
    final mapped = _failureFor(response);
    throw mapped;
  }

  Future<http.Response> _post(
    Uri uri,
    Map<String, Object?> body, {
    required bool submission,
  }) async {
    try {
      return await _client
          .post(
            uri,
            headers: {
              'accept': 'application/json',
              'apikey': publishableKey,
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw PublicIntakeFailure(
        PublicIntakeFailureCode.unavailable,
        outcomeUnknown: submission,
      );
    } on http.ClientException {
      throw PublicIntakeFailure(
        PublicIntakeFailureCode.unavailable,
        outcomeUnknown: submission,
      );
    }
  }

  PublicIntakeFailure _failureFor(http.Response response) {
    try {
      final decoded = _decodeObject(response.body);
      if (!_hasExactKeys(decoded, {'error'}) || decoded['error'] is! String) {
        return const PublicIntakeFailure(
          PublicIntakeFailureCode.invalidResponse,
          outcomeUnknown: true,
        );
      }
      final error = decoded['error'] as String;
      final expectedStatus = switch (error) {
        'validation' || 'bot_check_failed' => 400,
        'conflict' => 409,
        'rate_limited' => 429,
        'unavailable' => 503,
        _ => null,
      };
      if (expectedStatus != response.statusCode) {
        return const PublicIntakeFailure(
          PublicIntakeFailureCode.invalidResponse,
          outcomeUnknown: true,
        );
      }
      final retryAfter = response.headers['retry-after'];
      final retrySeconds = error == 'rate_limited' && retryAfter != null
          ? int.tryParse(retryAfter)
          : null;
      if (error == 'rate_limited' &&
          (retrySeconds == null || retrySeconds < 0)) {
        return const PublicIntakeFailure(
          PublicIntakeFailureCode.invalidResponse,
          outcomeUnknown: true,
        );
      }
      return PublicIntakeFailure(
        switch (error) {
          'validation' => PublicIntakeFailureCode.validation,
          'conflict' => PublicIntakeFailureCode.conflict,
          'rate_limited' => PublicIntakeFailureCode.rateLimited,
          'unavailable' => PublicIntakeFailureCode.unavailable,
          'bot_check_failed' => PublicIntakeFailureCode.botCheckFailed,
          _ => PublicIntakeFailureCode.invalidResponse,
        },
        outcomeUnknown: error == 'unavailable',
        retryAfterSeconds: retrySeconds,
      );
    } on FormatException {
      return const PublicIntakeFailure(
        PublicIntakeFailureCode.invalidResponse,
        outcomeUnknown: true,
      );
    } on TypeError {
      return const PublicIntakeFailure(
        PublicIntakeFailureCode.invalidResponse,
        outcomeUnknown: true,
      );
    }
  }

  Map<String, Object?> _decodeObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Expected an object');
    return Map<String, Object?>.from(decoded);
  }

  bool _hasExactKeys(Map<String, Object?> value, Set<String> keys) =>
      value.length == keys.length && value.keys.toSet().containsAll(keys);
}
