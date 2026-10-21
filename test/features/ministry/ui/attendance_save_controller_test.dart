import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/domain/session_navigation_context.dart';
import 'package:ieadpe_converts/features/ministry/ui/attendance_save_controller.dart';

import '../../../data/repositories_test.dart' as http_fixture;

const _congregationId = '11111111-1111-4111-8111-111111111111';
const _classId = '22222222-2222-4222-8222-222222222222';
const _sessionId = '33333333-3333-4333-8333-333333333333';
const _otherSessionId = '44444444-4444-4444-8444-444444444444';
const _operationA = '55555555-5555-4555-8555-555555555555';
const _operationB = '66666666-6666-4666-8666-666666666666';

final _context = SessionNavigationContext(
  congregationId: _congregationId,
  classId: _classId,
  sessionId: _sessionId,
);

final _otherContext = SessionNavigationContext(
  congregationId: _congregationId,
  classId: _classId,
  sessionId: _otherSessionId,
);

class _RecordedCall {
  const _RecordedCall(this.name, this.operationId, this.payload);

  final String name;
  final String operationId;
  final Map<String, Object?> payload;
}

typedef _CommandHandler = Future<Map<String, dynamic>> Function(
  _RecordedCall call,
);

class _Gateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();

  final calls = <_RecordedCall>[];
  _CommandHandler? handler;
  String actor = 'actor-a';

  @override
  String get context => '${boundary.generation}:$actor';

  @override
  void ensureCurrent(String context) {
    if (context != this.context) throw const DataFailure('stale');
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => const [];

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    return const {};
  }

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    final call = _RecordedCall(command, operationId, _snapshot(payload));
    calls.add(call);
    final handler = this.handler;
    if (handler == null) return _acknowledgement(call);
    return handler(call);
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

class _OperationIds {
  _OperationIds(this.values);

  final List<String> values;
  int calls = 0;

  String call() {
    if (calls >= values.length) throw StateError('Operation IDs exhausted.');
    return values[calls++];
  }
}

Map<String, Object?> _snapshot(Map<String, Object?> payload) => {
  for (final entry in payload.entries)
    entry.key: entry.key == 'marks' && entry.value is Map
        ? Map<String, Object?>.from(entry.value! as Map)
        : entry.value,
};

Map<String, dynamic> _acknowledgement(_RecordedCall call) => {
  'id': call.payload['session_id'],
  'revision': (call.payload['expected_revision']! as int) + 1,
};

({_Gateway gateway, AttendanceSaveController controller, _OperationIds ids})
_build() {
  final gateway = _Gateway();
  final ids = _OperationIds([_operationA, _operationB]);
  final controller = AttendanceSaveController(
    repository: MinistryRepository(gateway),
    createOperationId: ids.call,
  );
  return (gateway: gateway, controller: controller, ids: ids);
}

void main() {
  group('capture', () {
    test(
      'captures exact intent once and clears pending on acknowledgement',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);

        await harness.controller.submit(
          context: _context,
          expectedRevision: 7,
          marks: const {
            'enrollment-a': AttendanceStatus.present,
            'enrollment-b': AttendanceStatus.absent,
          },
          finalize: true,
        );

        expect(harness.gateway.calls, hasLength(1));
        final call = harness.gateway.calls.single;
        expect(call.name, 'save_attendance');
        expect(call.operationId, _operationA);
        expect(call.payload, {
          'congregation_id': _congregationId,
          'session_id': _sessionId,
          'expected_revision': 7,
          'marks': {'enrollment-a': 'present', 'enrollment-b': 'absent'},
          'finalize': true,
        });
        expect(harness.ids.calls, 1);
        expect(harness.controller.pending, isNull);
        expect(harness.controller.isBusy, isFalse);
        expect(harness.controller.hasUnknownResult, isFalse);
      },
    );

    test('rejects a non-positive expected revision before capturing', () async {
      final harness = _build();
      addTearDown(harness.controller.dispose);

      await expectLater(
        harness.controller.submit(
          context: _context,
          expectedRevision: 0,
          marks: const {'enrollment-a': AttendanceStatus.present},
          finalize: false,
        ),
        throwsA(
          isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
        ),
      );

      expect(harness.gateway.calls, isEmpty);
      expect(harness.controller.pending, isNull);
    });
  });

  group('ambiguous outcomes', () {
    test(
      'timeout and 5xx retain the command and retry the same intent',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        var attempt = 0;
        harness.gateway.handler = (call) async {
          attempt++;
          if (attempt == 1) throw TimeoutException('response lost');
          if (attempt == 2) throw const DataFailure('unavailable');
          if (attempt == 3) throw const DataFailure('backend');
          return _acknowledgement(call);
        };
        final marks = {
          'enrollment-a': AttendanceStatus.present,
          'enrollment-b': AttendanceStatus.absent,
        };

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 4,
            marks: marks,
            finalize: true,
          ),
          throwsA(isA<TimeoutException>()),
        );

        final pending = harness.controller.pending;
        expect(pending, isNotNull);
        expect(pending!.operationId, _operationA);
        expect(pending.finalize, isTrue);
        expect(harness.controller.isBusy, isFalse);
        expect(harness.controller.hasUnknownResult, isTrue);

        marks['enrollment-a'] = AttendanceStatus.absent;
        marks.remove('enrollment-b');
        marks['enrollment-c'] = AttendanceStatus.present;

        await expectLater(
          harness.controller.retryPending(),
          throwsA(
            isA<DataFailure>().having(
              (error) => error.code,
              'code',
              'unavailable',
            ),
          ),
        );
        await expectLater(
          harness.controller.retryPending(),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'backend'),
          ),
        );
        expect(harness.controller.pending, isNotNull);
        expect(harness.controller.hasUnknownResult, isTrue);
        expect(harness.controller.pending!.marks, {
          'enrollment-a': AttendanceStatus.present,
          'enrollment-b': AttendanceStatus.absent,
        });

        await harness.controller.retryPending();

        expect(harness.ids.calls, 1);
        expect(harness.gateway.calls, hasLength(4));
        expect(
          harness.gateway.calls.map((call) => call.operationId),
          everyElement(_operationA),
        );
        expect(harness.gateway.calls.map((call) => call.payload), [
          for (var index = 0; index < 4; index++)
            harness.gateway.calls.first.payload,
        ]);
        expect((harness.gateway.calls.last.payload['marks']! as Map), {
          'enrollment-a': 'present',
          'enrollment-b': 'absent',
        });
        expect(harness.gateway.calls.last.payload['finalize'], isTrue);
        expect(harness.controller.pending, isNull);
        expect(harness.controller.hasUnknownResult, isFalse);
      },
    );

    test(
      'mutating caller marks after capture cannot alter pending or retries',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        final marks = {
          'enrollment-a': AttendanceStatus.present,
          'enrollment-b': AttendanceStatus.absent,
        };
        var attempt = 0;
        harness.gateway.handler = (call) async {
          attempt++;
          if (attempt == 1) {
            marks['enrollment-a'] = AttendanceStatus.absent;
            marks.remove('enrollment-b');
            marks['enrollment-c'] = AttendanceStatus.present;
            throw const DataFailure('unavailable');
          }
          return _acknowledgement(call);
        };

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 2,
            marks: marks,
            finalize: false,
          ),
          throwsA(isA<DataFailure>()),
        );

        final pending = harness.controller.pending!;
        expect(pending.marks, {
          'enrollment-a': AttendanceStatus.present,
          'enrollment-b': AttendanceStatus.absent,
        });
        expect(
          () => pending.marks['enrollment-a'] = AttendanceStatus.absent,
          throwsUnsupportedError,
        );

        await harness.controller.retryPending();

        expect(harness.gateway.calls, hasLength(2));
        expect(
          harness.gateway.calls.first.payload,
          harness.gateway.calls.last.payload,
        );
        expect((harness.gateway.calls.last.payload['marks']! as Map), {
          'enrollment-a': 'present',
          'enrollment-b': 'absent',
        });
      },
    );

    test(
      'operation conflict stays unknown and never fabricates success',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        var conflict = true;
        harness.gateway.handler = (call) async {
          if (conflict) throw const DataFailure('backend');
          return _acknowledgement(call);
        };

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.present},
            finalize: true,
          ),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'backend'),
          ),
        );

        expect(harness.controller.pending, isNotNull);
        expect(harness.controller.hasUnknownResult, isTrue);
        expect(harness.gateway.calls, hasLength(1));

        conflict = false;
        await harness.controller.retryPending();

        expect(harness.gateway.calls, hasLength(2));
        expect(harness.gateway.calls[1].operationId, _operationA);
        expect(
          harness.gateway.calls[1].payload,
          harness.gateway.calls[0].payload,
        );
        expect(harness.controller.pending, isNull);
      },
    );

    test(
      'generic invalid remains ambiguous because it may be a receipt conflict',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        var conflict = true;
        harness.gateway.handler = (call) async {
          if (conflict) throw const DataFailure('invalid');
          return _acknowledgement(call);
        };

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 3,
            marks: const {'enrollment-a': AttendanceStatus.present},
            finalize: true,
          ),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
          ),
        );

        expect(harness.controller.pending, isNotNull);
        expect(harness.controller.hasUnknownResult, isTrue);
        expect(harness.controller.isBusy, isFalse);

        conflict = false;
        await harness.controller.retryPending();

        expect(harness.gateway.calls, hasLength(2));
        expect(harness.gateway.calls[1].operationId, _operationA);
        expect(
          harness.gateway.calls[1].payload,
          harness.gateway.calls[0].payload,
        );
        expect(harness.gateway.calls[1].payload['finalize'], isTrue);
        expect(harness.controller.pending, isNull);
      },
    );

    test(
      'real loopback operation conflict stays unknown and retries exact intent',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final gateway = await http_fixture.fixture((request) async {
          expect(
            request.uri.path,
            '/rest/v1/rpc/ieadpe_ministry_save_attendance',
          );
          final body = Map<String, dynamic>.from(
            jsonDecode(await utf8.decoder.bind(request).join()) as Map,
          );
          bodies.add(body);
          if (bodies.length == 1) {
            await http_fixture.respond(request, {
              'code': '22023',
              'message': 'operation_conflict',
              'details': null,
              'hint': null,
            }, 400);
            return;
          }
          await http_fixture.respond(request, {
            'id': _sessionId,
            'revision': 2,
            'status': 'open',
            'roster_frozen': true,
            'attendance_count': 1,
          });
        });
        final controller = AttendanceSaveController(
          repository: MinistryRepository(gateway),
          createOperationId: () => _operationA,
        );
        addTearDown(controller.dispose);

        await expectLater(
          controller.submit(
            context: _context,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.present},
            finalize: true,
          ),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
          ),
        );

        expect(controller.pending, isNotNull);
        expect(controller.hasUnknownResult, isTrue);

        await controller.retryPending();

        expect(bodies, hasLength(2));
        expect(bodies[0]['operation_id'], _operationA);
        expect(bodies[1]['operation_id'], _operationA);
        expect(bodies[1]['payload'], bodies[0]['payload']);
        final payload = Map<String, Object?>.from(bodies[1]['payload']! as Map);
        expect(payload['finalize'], isTrue);
        expect(payload['marks'], {'enrollment-a': 'present'});
        expect(controller.pending, isNull);
      },
    );
  });

  group('rejections and alternate intent', () {
    for (final code in ['stale_revision']) {
      test(
        'proven $code rejection stays pending until explicit clear',
        () async {
          final harness = _build();
          addTearDown(harness.controller.dispose);
          var fail = true;
          harness.gateway.handler = (call) async {
            if (fail) throw DataFailure(code);
            return _acknowledgement(call);
          };

          await expectLater(
            harness.controller.submit(
              context: _context,
              expectedRevision: 3,
              marks: const {'enrollment-a': AttendanceStatus.present},
              finalize: true,
            ),
            throwsA(
              isA<DataFailure>().having((error) => error.code, 'code', code),
            ),
          );

          expect(harness.controller.pending!.operationId, _operationA);
          expect(harness.controller.isBusy, isFalse);
          expect(harness.controller.hasUnknownResult, isFalse);
          await expectLater(
            harness.controller.retryPending(),
            throwsStateError,
          );
          await expectLater(
            harness.controller.submit(
              context: _otherContext,
              expectedRevision: 1,
              marks: const {'enrollment-a': AttendanceStatus.absent},
              finalize: false,
            ),
            throwsStateError,
          );
          expect(harness.ids.calls, 1);
          expect(harness.gateway.calls, hasLength(1));

          harness.controller.clear();
          expect(harness.controller.pending, isNull);

          fail = false;
          await harness.controller.submit(
            context: _otherContext,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.absent},
            finalize: false,
          );

          expect(harness.ids.calls, 2);
          expect(harness.gateway.calls, hasLength(2));
          expect(harness.gateway.calls.last.operationId, _operationB);
          expect(
            harness.gateway.calls.last.payload['session_id'],
            _otherSessionId,
          );
          expect(harness.gateway.calls.last.payload['finalize'], isFalse);
        },
      );
    }

    test(
      'alternate submit while unresolved is rejected without another ID',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        final response = Completer<Map<String, dynamic>>();
        harness.gateway.handler = (call) => response.future;

        final first = harness.controller.submit(
          context: _context,
          expectedRevision: 1,
          marks: const {'enrollment-a': AttendanceStatus.present},
          finalize: true,
        );
        await pumpEventQueue();

        expect(harness.controller.pending!.operationId, _operationA);
        expect(harness.controller.isBusy, isTrue);
        await expectLater(
          harness.controller.submit(
            context: _otherContext,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.absent},
            finalize: false,
          ),
          throwsStateError,
        );
        await expectLater(harness.controller.retryPending(), throwsStateError);
        expect(harness.ids.calls, 1);

        response.complete(_acknowledgement(harness.gateway.calls.single));
        await first;

        expect(harness.controller.pending, isNull);
        expect(harness.controller.isBusy, isFalse);
      },
    );
  });

  group('boundary and lifecycle', () {
    test('security invalidation clears synchronously and discards late acknowledgement', () async {
      final harness = _build();
      addTearDown(harness.controller.dispose);
      final response = Completer<Map<String, dynamic>>();
      harness.gateway.handler = (call) => response.future;

      final submit = harness.controller.submit(
        context: _context,
        expectedRevision: 1,
        marks: const {'enrollment-a': AttendanceStatus.present},
        finalize: true,
      );
      final expectation = expectLater(
        submit,
        throwsA(
          isA<DataFailure>().having((error) => error.code, 'code', 'stale'),
        ),
      );
      await pumpEventQueue();
      expect(harness.controller.isBusy, isTrue);

      harness.gateway.boundary.invalidate();

      expect(harness.controller.pending, isNull);
      expect(harness.controller.isBusy, isFalse);
      expect(harness.controller.hasUnknownResult, isFalse);

      response.complete(_acknowledgement(harness.gateway.calls.single));
      await expectation;

      expect(harness.controller.pending, isNull);
      expect(harness.controller.hasUnknownResult, isFalse);
      expect(harness.gateway.calls, hasLength(1));
    });

    test('same-boundary actor change clears pending before exposure', () async {
      final harness = _build();
      addTearDown(harness.controller.dispose);
      harness.gateway.handler = (call) async =>
          throw const DataFailure('unavailable');

      await expectLater(
        harness.controller.submit(
          context: _context,
          expectedRevision: 1,
          marks: const {'enrollment-a': AttendanceStatus.present},
          finalize: true,
        ),
        throwsA(isA<DataFailure>()),
      );
      expect(harness.controller.pending, isNotNull);

      harness.gateway.actor = 'actor-b';

      expect(harness.controller.pending, isNull);
      expect(harness.controller.isBusy, isFalse);
      expect(harness.controller.hasUnknownResult, isFalse);
      await expectLater(harness.controller.retryPending(), throwsStateError);
      expect(harness.gateway.calls, hasLength(1));
    });

    test(
      'same-boundary actor change blocks retry before any new command',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        harness.gateway.handler = (call) async =>
            throw const DataFailure('unavailable');

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.present},
            finalize: true,
          ),
          throwsA(isA<DataFailure>()),
        );

        harness.gateway.actor = 'actor-b';

        await expectLater(harness.controller.retryPending(), throwsStateError);
        expect(harness.controller.pending, isNull);
        expect(harness.controller.hasUnknownResult, isFalse);
        expect(harness.gateway.calls, hasLength(1));
        expect(harness.gateway.calls.single.operationId, _operationA);
      },
    );

    test('same-boundary actor change discards a late success', () async {
      final harness = _build();
      addTearDown(harness.controller.dispose);
      final response = Completer<Map<String, dynamic>>();
      harness.gateway.handler = (call) => response.future;

      final submit = harness.controller.submit(
        context: _context,
        expectedRevision: 1,
        marks: const {'enrollment-a': AttendanceStatus.present},
        finalize: true,
      );
      final expectation = expectLater(
        submit,
        throwsA(
          isA<DataFailure>().having((error) => error.code, 'code', 'stale'),
        ),
      );
      await pumpEventQueue();

      harness.gateway.actor = 'actor-b';
      response.complete(_acknowledgement(harness.gateway.calls.single));
      await expectation;

      expect(harness.controller.pending, isNull);
      expect(harness.controller.isBusy, isFalse);
      expect(harness.controller.hasUnknownResult, isFalse);
      expect(harness.gateway.calls, hasLength(1));
    });

    test('same-boundary actor change discards a late error', () async {
      final harness = _build();
      addTearDown(harness.controller.dispose);
      final response = Completer<Map<String, dynamic>>();
      harness.gateway.handler = (call) => response.future;

      final submit = harness.controller.submit(
        context: _context,
        expectedRevision: 1,
        marks: const {'enrollment-a': AttendanceStatus.present},
        finalize: true,
      );
      final expectation = expectLater(
        submit,
        throwsA(
          isA<DataFailure>().having((error) => error.code, 'code', 'stale'),
        ),
      );
      await pumpEventQueue();

      harness.gateway.actor = 'actor-b';
      response.completeError(const DataFailure('backend'));
      await expectation;

      expect(harness.controller.pending, isNull);
      expect(harness.controller.isBusy, isFalse);
      expect(harness.controller.hasUnknownResult, isFalse);
      expect(harness.gateway.calls, hasLength(1));
    });

    test(
      'obsolete success cannot discard newer cross-generation intent',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        final firstResponse = Completer<Map<String, dynamic>>();
        final secondResponse = Completer<Map<String, dynamic>>();
        harness.gateway.handler = (call) => call.operationId == _operationA
            ? firstResponse.future
            : secondResponse.future;

        final first = harness.controller.submit(
          context: _context,
          expectedRevision: 1,
          marks: const {'enrollment-a': AttendanceStatus.present},
          finalize: true,
        );
        final firstExpectation = expectLater(
          first,
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'stale'),
          ),
        );
        await pumpEventQueue();

        harness.gateway.boundary.invalidate();
        harness.controller.clear();
        final second = harness.controller.submit(
          context: _otherContext,
          expectedRevision: 9,
          marks: const {'enrollment-b': AttendanceStatus.absent},
          finalize: false,
        );
        await pumpEventQueue();

        final pending = harness.controller.pending!;
        expect(pending.operationId, _operationB);
        expect(pending.context, _otherContext);
        expect(pending.expectedRevision, 9);
        expect(pending.marks, {'enrollment-b': AttendanceStatus.absent});
        expect(pending.finalize, isFalse);
        expect(harness.controller.isBusy, isTrue);
        expect(harness.controller.hasUnknownResult, isFalse);

        firstResponse.complete(_acknowledgement(harness.gateway.calls.first));
        await firstExpectation;

        expect(harness.controller.pending, same(pending));
        expect(harness.controller.pending!.operationId, _operationB);
        expect(harness.controller.pending!.finalize, isFalse);
        expect(harness.controller.isBusy, isTrue);
        expect(harness.controller.hasUnknownResult, isFalse);

        secondResponse.complete(_acknowledgement(harness.gateway.calls.last));
        await second;
        expect(harness.controller.pending, isNull);
      },
    );

    test(
      'obsolete error cannot discard newer cross-generation intent',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        final firstResponse = Completer<Map<String, dynamic>>();
        final secondResponse = Completer<Map<String, dynamic>>();
        harness.gateway.handler = (call) => call.operationId == _operationA
            ? firstResponse.future
            : secondResponse.future;

        final first = harness.controller.submit(
          context: _context,
          expectedRevision: 1,
          marks: const {'enrollment-a': AttendanceStatus.present},
          finalize: true,
        );
        final firstExpectation = expectLater(
          first,
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'stale'),
          ),
        );
        await pumpEventQueue();

        harness.gateway.boundary.invalidate();
        harness.controller.clear();
        final second = harness.controller.submit(
          context: _otherContext,
          expectedRevision: 9,
          marks: const {'enrollment-b': AttendanceStatus.absent},
          finalize: false,
        );
        await pumpEventQueue();

        final pending = harness.controller.pending!;
        expect(pending.operationId, _operationB);
        expect(pending.context, _otherContext);
        expect(pending.expectedRevision, 9);
        expect(pending.marks, {'enrollment-b': AttendanceStatus.absent});
        expect(pending.finalize, isFalse);
        expect(harness.controller.isBusy, isTrue);
        expect(harness.controller.hasUnknownResult, isFalse);

        firstResponse.completeError(const DataFailure('backend'));
        await firstExpectation;

        expect(harness.controller.pending, same(pending));
        expect(harness.controller.pending!.operationId, _operationB);
        expect(harness.controller.pending!.finalize, isFalse);
        expect(harness.controller.isBusy, isTrue);
        expect(harness.controller.hasUnknownResult, isFalse);

        secondResponse.complete(_acknowledgement(harness.gateway.calls.last));
        await second;
        expect(harness.controller.pending, isNull);
      },
    );

    test(
      'permission loss clears protected pending data instead of retaining it',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        harness.gateway.handler = (call) async =>
            throw const DataFailure('permission');

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.present},
            finalize: true,
          ),
          throwsA(
            isA<DataFailure>().having(
              (error) => error.code,
              'code',
              'permission',
            ),
          ),
        );

        expect(harness.controller.pending, isNull);
        expect(harness.controller.isBusy, isFalse);
        expect(harness.controller.hasUnknownResult, isFalse);
        await expectLater(harness.controller.retryPending(), throwsStateError);
      },
    );

    test(
      'clear during submit discards late reply and leaves new intent intact',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        final firstResponse = Completer<Map<String, dynamic>>();
        final secondResponse = Completer<Map<String, dynamic>>();
        harness.gateway.handler = (call) => call.operationId == _operationA
            ? firstResponse.future
            : secondResponse.future;

        final first = harness.controller.submit(
          context: _context,
          expectedRevision: 1,
          marks: const {'enrollment-a': AttendanceStatus.present},
          finalize: true,
        );
        await pumpEventQueue();
        harness.controller.clear();
        expect(harness.controller.pending, isNull);

        final second = harness.controller.submit(
          context: _otherContext,
          expectedRevision: 1,
          marks: const {'enrollment-a': AttendanceStatus.absent},
          finalize: false,
        );
        await pumpEventQueue();
        expect(harness.controller.pending!.operationId, _operationB);
        expect(harness.controller.isBusy, isTrue);

        firstResponse.complete(_acknowledgement(harness.gateway.calls.first));
        await first;
        expect(harness.controller.pending!.operationId, _operationB);
        expect(harness.controller.isBusy, isTrue);

        secondResponse.complete(_acknowledgement(harness.gateway.calls.last));
        await second;
        expect(harness.controller.pending, isNull);
        expect(harness.controller.isBusy, isFalse);
        expect(harness.gateway.calls, hasLength(2));
      },
    );

    test('pending state survives reads and is controller-local', () async {
      final first = _build();
      final second = _build();
      addTearDown(first.controller.dispose);
      addTearDown(second.controller.dispose);
      first.gateway.handler = (call) async =>
          throw const DataFailure('unavailable');

      await expectLater(
        first.controller.submit(
          context: _context,
          expectedRevision: 1,
          marks: const {'enrollment-a': AttendanceStatus.present},
          finalize: true,
        ),
        throwsA(isA<DataFailure>()),
      );

      final pending = first.controller.pending!;
      expect(pending.operationId, _operationA);
      expect(pending.context, _context);
      expect(pending.expectedRevision, 1);
      expect(pending.finalize, isTrue);
      expect(pending.protectedGeneration, first.gateway.boundary.generation);
      expect(pending.protectedContext, first.gateway.context);
      expect(first.controller.pending!.operationId, _operationA);
      expect(second.controller.pending, isNull);
      expect(second.controller.hasUnknownResult, isFalse);
    });

    test('dispose clears pending and ignores a late acknowledgement', () async {
      final harness = _build();
      final response = Completer<Map<String, dynamic>>();
      harness.gateway.handler = (call) => response.future;

      final submit = harness.controller.submit(
        context: _context,
        expectedRevision: 1,
        marks: const {'enrollment-a': AttendanceStatus.present},
        finalize: true,
      );
      await pumpEventQueue();
      expect(harness.controller.pending, isNotNull);

      harness.controller.dispose();
      expect(harness.controller.pending, isNull);
      expect(harness.controller.isBusy, isFalse);

      response.complete(_acknowledgement(harness.gateway.calls.single));
      await submit;

      expect(harness.controller.pending, isNull);
      expect(harness.gateway.calls, hasLength(1));
    });
  });

  group('pre-dispatch invalidation', () {
    test('clear from submitting listener sends no command', () async {
      final harness = _build();
      addTearDown(harness.controller.dispose);
      harness.gateway.handler = (call) async => _acknowledgement(call);
      var cleared = false;
      harness.controller.addListener(() {
        if (!cleared && harness.controller.isBusy) {
          cleared = true;
          harness.controller.clear();
        }
      });

      await harness.controller.submit(
        context: _context,
        expectedRevision: 1,
        marks: const {'enrollment-a': AttendanceStatus.present},
        finalize: true,
      );

      expect(cleared, isTrue);
      expect(harness.gateway.calls, isEmpty);
      expect(harness.controller.pending, isNull);
      expect(harness.controller.isBusy, isFalse);
      expect(harness.controller.hasUnknownResult, isFalse);
    });

    test(
      'real gateway clear from submitting listener sends no HTTP request',
      () async {
        var requests = 0;
        final gateway = await http_fixture.fixture((request) async {
          requests++;
          await http_fixture.respond(request, {
            'id': _sessionId,
            'revision': 2,
            'status': 'finalized',
            'roster_frozen': true,
            'attendance_count': 1,
          });
        });
        final controller = AttendanceSaveController(
          repository: MinistryRepository(gateway),
          createOperationId: () => _operationA,
        );
        addTearDown(controller.dispose);
        var cleared = false;
        controller.addListener(() {
          if (!cleared && controller.isBusy) {
            cleared = true;
            controller.clear();
          }
        });

        await controller.submit(
          context: _context,
          expectedRevision: 1,
          marks: const {'enrollment-a': AttendanceStatus.present},
          finalize: true,
        );

        expect(cleared, isTrue);
        expect(controller.pending, isNull);
        expect(requests, 0);
      },
    );

    test(
      'boundary invalidation from submitting listener sends no command',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        harness.gateway.handler = (call) async => _acknowledgement(call);
        var invalidated = false;
        harness.controller.addListener(() {
          if (!invalidated && harness.controller.isBusy) {
            invalidated = true;
            harness.gateway.boundary.invalidate();
          }
        });

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.present},
            finalize: true,
          ),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'stale'),
          ),
        );

        expect(invalidated, isTrue);
        expect(harness.gateway.calls, isEmpty);
        expect(harness.controller.pending, isNull);
        expect(harness.controller.isBusy, isFalse);
        expect(harness.controller.hasUnknownResult, isFalse);
      },
    );

    test(
      'actor context invalidation from submitting listener sends no command',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        harness.gateway.handler = (call) async => _acknowledgement(call);
        var changed = false;
        harness.controller.addListener(() {
          if (!changed && harness.controller.isBusy) {
            changed = true;
            harness.gateway.actor = 'actor-b';
          }
        });

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.present},
            finalize: true,
          ),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'stale'),
          ),
        );

        expect(changed, isTrue);
        expect(harness.gateway.calls, isEmpty);
        expect(harness.controller.pending, isNull);
        expect(harness.controller.isBusy, isFalse);
        expect(harness.controller.hasUnknownResult, isFalse);
      },
    );

    test(
      'clear from submitting listener during retry sends no second command',
      () async {
        final harness = _build();
        addTearDown(harness.controller.dispose);
        harness.gateway.handler = (call) async =>
            throw const DataFailure('unavailable');

        await expectLater(
          harness.controller.submit(
            context: _context,
            expectedRevision: 1,
            marks: const {'enrollment-a': AttendanceStatus.present},
            finalize: true,
          ),
          throwsA(isA<DataFailure>()),
        );
        expect(harness.gateway.calls, hasLength(1));

        var cleared = false;
        harness.controller.addListener(() {
          if (!cleared && harness.controller.isBusy) {
            cleared = true;
            harness.controller.clear();
          }
        });

        await harness.controller.retryPending();

        expect(cleared, isTrue);
        expect(harness.gateway.calls, hasLength(1));
        expect(harness.controller.pending, isNull);
        expect(harness.controller.isBusy, isFalse);
        expect(harness.controller.hasUnknownResult, isFalse);
      },
    );
  });
}
