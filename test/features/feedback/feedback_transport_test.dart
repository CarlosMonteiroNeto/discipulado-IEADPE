import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/feedback/feedback_repository.dart';

import '../../data/repositories_test.dart' show fixture, respond, operationId;

void main() {
  test(
    'production gateway accepts minimal feedback envelopes and bounds reads',
    () async {
      final commands = <String>[];
      final gateway = await fixture((request) async {
        if (request.uri.path.endsWith('/feedback')) {
          expect(request.uri.queryParameters['limit'], '100');
          await respond(request, []);
          return;
        }
        commands.add(request.uri.path);
        final payload =
            jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(payload['operation_id'], operationId);
        expect(
          (payload['payload'] as Map).keys,
          request.uri.path.endsWith('submit_feedback')
              ? ['message']
              : ['id', 'status'],
        );
        await respond(request, {'id': operationId});
      });
      final repository = FeedbackRepository(gateway);
      expect(
        (await repository.submit('Sugestão', operationId)).status,
        MutationStatus.applied,
      );
      expect(
        (await repository.update(
          operationId,
          FeedbackStatus.read,
          operationId,
        )).status,
        MutationStatus.applied,
      );
      expect(await repository.list(), isEmpty);
      expect(commands, [
        '/rest/v1/rpc/ieadpe_submit_feedback',
        '/rest/v1/rpc/ieadpe_update_feedback',
      ]);
    },
  );
  test(
    'production gateway rejects spoofed identity without issuing HTTP',
    () async {
      var requests = 0;
      final gateway = await fixture((request) async {
        requests++;
        await respond(request, {});
      });
      await expectLater(
        gateway.command('submit_feedback', operationId, {
          'message': 'Spoof',
          'created_by': operationId,
        }),
        throwsA(anything),
      );
      expect(requests, 0);
    },
  );
}
