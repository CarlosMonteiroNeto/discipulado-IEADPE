import 'package:flutter_test/flutter_test.dart';

import '../../data/repositories_test.dart' show fixture, respond;

import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';

void main() {
  test(
    'catalog commands reach RPC and reject actor overrides before transport',
    () async {
      var calls = 0;
      final gateway = await fixture((r) async {
        calls++;
        expect(r.uri.path, '/rest/v1/rpc/ieadpe_save_congregation');
        await respond(r, {'id': '10000000-0000-0000-0000-000000000001'});
      });
      final result = await gateway.command(
        'save_congregation',
        '30000000-0000-0000-0000-000000000001',
        {'name': 'Sede'},
      );
      expect(result.status, MutationStatus.applied);
      expect(calls, 1);
      await expectLater(
        gateway.command(
          'save_congregation',
          '30000000-0000-0000-0000-000000000002',
          {'name': 'Sede', 'created_by': 'spoof'},
        ),
        throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'invalid')),
      );
      expect(calls, 1);
    },
  );
}
