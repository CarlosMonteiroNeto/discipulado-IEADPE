import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/intake/intake_models.dart';
import 'package:ieadpe_converts/features/intake/public_intake_repository.dart';

const congregationId = '11111111-1111-4111-8111-111111111111';
const submissionId = '22222222-2222-4222-8222-222222222222';

ConvertDraft draft({Uint8List? photoBytes, bool removePhoto = false}) =>
    ConvertDraft(
      name: 'Ana Maria',
      landmark: 'Ao lado da praça',
      gender: Gender.female,
      conversionDate: DateOnly(2026, 10, 25),
      worshipType: 'Culto de celebração',
      address: 'Rua Um, 10',
      congregationId: congregationId,
      photoBytes: photoBytes,
      removePhoto: removePhoto,
    );

PublicIntakeRepository repository(
  http.Client client, {
  Duration timeout = const Duration(seconds: 15),
}) => PublicIntakeRepository(
  supabaseUrl: Uri.parse('https://project.supabase.co'),
  publishableKey: 'sb_publishable_public-test',
  client: client,
  requestTimeout: timeout,
);

Map<String, Object?> catalogResponse({
  List<Map<String, Object?>>? items,
  String? nextCursor,
}) => {
  'items':
      items ??
      [
        {'id': congregationId, 'name': 'Congregação Central'},
      ],
  'next_cursor': nextCursor,
};

void main() {
  test('catalog uses the names-only public RPC contract', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode(catalogResponse()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final publicRepository = repository(client);

    final page = await publicRepository.listCongregations();

    expect(page.items, const [
      PublicCongregation(id: congregationId, name: 'Congregação Central'),
    ]);
    expect(
      captured!.url.toString(),
      'https://project.supabase.co/rest/v1/rpc/ieadpe_public_congregations',
    );
    expect(captured!.headers['apikey'], 'sb_publishable_public-test');
    expect(captured!.headers.containsKey('authorization'), isFalse);
    expect(jsonDecode(captured!.body), {
      'request': {'limit': 100, 'cursor': null},
    });
  });

  test(
    'catalog rejects fields outside the public names-only projection',
    () async {
      final publicRepository = repository(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'items': [
                {
                  'id': congregationId,
                  'name': 'Congregação Central',
                  'address': 'private',
                },
              ],
              'next_cursor': null,
            }),
            200,
          ),
        ),
      );

      await expectLater(
        publicRepository.listCongregations(),
        throwsA(
          isA<PublicIntakeFailure>().having(
            (failure) => failure.code,
            'code',
            PublicIntakeFailureCode.invalidResponse,
          ),
        ),
      );
    },
  );

  test('public draft preserves canonical fields and omits photo assets', () {
    final payload = PublicIntakeDraft.fromConvertDraft(draft()).toJson();

    expect(payload, {
      'congregation_id': congregationId,
      'person': {
        'name': 'Ana Maria',
        'phone': null,
        'birth_date': null,
        'address': {
          'street': 'Rua Um, 10',
          'district': null,
          'city': null,
          'postal_code': null,
          'state_code': null,
        },
      },
      'convert': {
        'landmark': 'Ao lado da praça',
        'gender': 'female',
        'conversion_date': '2026-10-25',
        'worship_type': 'Culto de celebração',
        'age': null,
      },
    });
    expect(
      () => PublicIntakeDraft.fromConvertDraft(
        draft(photoBytes: Uint8List.fromList([1])),
      ),
      throwsArgumentError,
    );
    expect(
      () => PublicIntakeDraft.fromConvertDraft(draft(removePhoto: true)),
      throwsArgumentError,
    );
  });

  test('submit sends only the locked public wire fields', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{"status":"received"}', 202);
    });
    final publicRepository = repository(client);
    final publicDraft = PublicIntakeDraft.fromConvertDraft(draft());

    await publicRepository.submit(
      submissionId: submissionId,
      turnstileToken: 'fresh-turnstile-token',
      draft: publicDraft,
    );

    expect(captured!.method, 'POST');
    expect(
      captured!.url.toString(),
      'https://project.supabase.co/functions/v1/public-intake',
    );
    expect(captured!.headers['apikey'], 'sb_publishable_public-test');
    expect(captured!.headers.containsKey('authorization'), isFalse);
    expect(jsonDecode(captured!.body), {
      'submission_id': submissionId,
      'turnstile_token': 'fresh-turnstile-token',
      'draft': publicDraft.toJson(),
    });
    expect(utf8.encode(captured!.body).length, lessThanOrEqualTo(16 * 1024));
  });

  test('unavailable response keeps the submission outcome unknown', () async {
    final publicRepository = repository(
      MockClient((_) async => http.Response('{"error":"unavailable"}', 503)),
    );

    await expectLater(
      publicRepository.submit(
        submissionId: submissionId,
        turnstileToken: 'fresh-turnstile-token',
        draft: PublicIntakeDraft.fromConvertDraft(draft()),
      ),
      throwsA(
        isA<PublicIntakeFailure>()
            .having(
              (failure) => failure.code,
              'code',
              PublicIntakeFailureCode.unavailable,
            )
            .having(
              (failure) => failure.outcomeUnknown,
              'outcomeUnknown',
              true,
            ),
      ),
    );
  });

  test('rate-limited response preserves the integer retry contract', () async {
    final publicRepository = repository(
      MockClient(
        (_) async => http.Response(
          '{"error":"rate_limited"}',
          429,
          headers: {'retry-after': '3600'},
        ),
      ),
    );

    await expectLater(
      publicRepository.submit(
        submissionId: submissionId,
        turnstileToken: 'fresh-turnstile-token',
        draft: PublicIntakeDraft.fromConvertDraft(draft()),
      ),
      throwsA(
        isA<PublicIntakeFailure>()
            .having(
              (failure) => failure.code,
              'code',
              PublicIntakeFailureCode.rateLimited,
            )
            .having((failure) => failure.retryAfterSeconds, 'retryAfter', 3600)
            .having(
              (failure) => failure.outcomeUnknown,
              'outcomeUnknown',
              false,
            ),
      ),
    );
  });
}
