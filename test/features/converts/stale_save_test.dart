import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/converts/convert_save_controller.dart';

import 'save_test.dart';

void main() {
  test(
    'an old form cannot retry its retained payload under a new context',
    () async {
      final gateway = TestGateway();
      final saver = ConvertSaveController(gateway: gateway, photos: NoPhotos());
      await expectLater(saver.save(draft()), throwsA(isA<DataFailure>()));
      gateway.boundary.invalidate();
      gateway.fail = false;
      await expectLater(
        saver.save(draft()),
        throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
      );
      expect(gateway.calls.length, 1);
    },
  );
}
