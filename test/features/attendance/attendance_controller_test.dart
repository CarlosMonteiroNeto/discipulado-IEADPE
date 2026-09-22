import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attendance_test_support.dart';

JsonMap view({
  String date = '2026-01-10',
  int revision = 1,
  String status = 'open',
  List<JsonMap>? roster,
}) => attendanceViewJson(
  session: sessionJson(
    id: 'ses1',
    classId: 'cls1',
    date: date,
    status: status,
    revision: revision,
  ),
  roster:
      roster ??
      <JsonMap>[
        rosterEntryJson(
          enrollmentId: 'e1',
          studentId: 's1',
          studentName: 'Ana Souza',
          status: 'unmarked',
        ),
      ],
);

void main() {
  test('initial load keeps an unmarked roster entry unmarked', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => view();
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.statusOf('e1'), AttendanceStatus.unmarked);
    expect(controller.isDirty, isFalse);
  });

  test('Marcar todos presentes stays unsaved until Salvar chamada', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) =>
          operation == 'saveAttendance'
          ? const <String, Object?>{'id': 'ses1', 'revision': 2}
          : view(
              roster: <JsonMap>[
                rosterEntryJson(
                  enrollmentId: 'e1',
                  studentId: 's1',
                  studentName: 'Ana Souza',
                ),
                rosterEntryJson(
                  enrollmentId: 'e2',
                  studentId: 's2',
                  studentName: 'Bruno Lima',
                ),
              ],
            );
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();
    controller.markAllPresent();

    expect(controller.statusOf('e1'), AttendanceStatus.present);
    expect(controller.isDirty, isTrue);
    expect(
      gateway.invocations.where(
        (({String operation, JsonMap payload}) call) =>
            call.operation == 'saveAttendance',
      ),
      isEmpty,
    );

    final bool saved = await controller.save(finalize: false);

    expect(saved, isTrue);
    final JsonMap payload = gateway.invocations
        .lastWhere(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'saveAttendance',
        )
        .payload;
    expect(payload['attendance'], <String, Object?>{
      'e1': 'present',
      'e2': 'present',
    });
    expect(controller.isDirty, isFalse);
  });

  test('save submits every enrolled status keyed by enrollment ID', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) =>
          operation == 'saveAttendance'
          ? const <String, Object?>{'id': 'ses1', 'revision': 4}
          : view(
              revision: 3,
              roster: <JsonMap>[
                rosterEntryJson(
                  enrollmentId: 'e1',
                  studentId: 's1',
                  studentName: 'Ana',
                ),
                rosterEntryJson(
                  enrollmentId: 'e2',
                  studentId: 's2',
                  studentName: 'Bruno',
                ),
                rosterEntryJson(
                  enrollmentId: 'e3',
                  studentId: 's3',
                  studentName: 'Carla',
                ),
                rosterEntryJson(
                  enrollmentId: 'e4',
                  studentId: 's4',
                  studentName: 'Diego',
                ),
              ],
            );
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();
    controller.mark('e1', AttendanceStatus.present);
    controller.mark('e2', AttendanceStatus.absent);
    controller.mark('e3', AttendanceStatus.excused);

    await controller.save(finalize: false);

    final JsonMap payload = gateway.invocations
        .lastWhere(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'saveAttendance',
        )
        .payload;
    expect(payload['expectedRevision'], 3);
    expect(payload['finalize'], false);
    expect(payload['attendance'], <String, Object?>{
      'e1': 'present',
      'e2': 'absent',
      'e3': 'excused',
      'e4': 'unmarked',
    });
  });

  test('the concluded flag loads from the session and submits with the save',
      () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) =>
          operation == 'saveAttendance'
          ? const <String, Object?>{'id': 'ses1', 'revision': 2}
          : attendanceViewJson(
              session: sessionJson(
                id: 'ses1',
                classId: 'cls1',
                date: '2026-01-10',
                lessonFinished: true,
              ),
              roster: <JsonMap>[
                rosterEntryJson(
                  enrollmentId: 'e1',
                  studentId: 's1',
                  studentName: 'Ana Souza',
                  status: 'present',
                ),
              ],
            );
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.lessonFinished, isTrue);
    expect(controller.isDirty, isFalse);

    controller.setLessonFinished(false);
    final bool saved = await controller.save(finalize: false);

    expect(saved, isTrue);
    final JsonMap payload = gateway.invocations
        .lastWhere(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'saveAttendance',
        )
        .payload;
    expect(payload['lessonFinished'], isFalse);
  });

  test('finalization is refused while any member is unmarked', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => view(
        roster: <JsonMap>[
          rosterEntryJson(
            enrollmentId: 'e1',
            studentId: 's1',
            studentName: 'Ana',
          ),
          rosterEntryJson(
            enrollmentId: 'e2',
            studentId: 's2',
            studentName: 'Bruno',
          ),
        ],
      );
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();
    controller.mark('e1', AttendanceStatus.present);

    final bool saved = await controller.save(finalize: true);

    expect(saved, isFalse);
    expect(controller.validationMessage, isNotNull);
    expect(
      gateway.invocations.where(
        (({String operation, JsonMap payload}) call) =>
            call.operation == 'saveAttendance',
      ),
      isEmpty,
    );
  });

  test('finalization is refused for a future session date', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => view(
        date: '2099-01-01',
        roster: <JsonMap>[
          rosterEntryJson(
            enrollmentId: 'e1',
            studentId: 's1',
            studentName: 'Ana',
            status: 'present',
          ),
        ],
      );
    final AttendanceController controller = attendanceController(
      gateway,
      nowUtc: () => DateTime.utc(2026, 1, 10),
    );
    addTearDown(controller.dispose);

    await controller.load();

    final bool saved = await controller.save(finalize: true);

    expect(saved, isFalse);
    expect(controller.validationMessage, contains('futura'));
    expect(
      gateway.invocations.where(
        (({String operation, JsonMap payload}) call) =>
            call.operation == 'saveAttendance',
      ),
      isEmpty,
    );
  });

  test('a stale save keeps the unsaved choices and request identity', () async {
    bool conflict = true;
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) {
        if (operation == 'getSessionAttendance') {
          return view(
            revision: conflict ? 1 : 2,
            roster: <JsonMap>[
              rosterEntryJson(
                enrollmentId: 'e1',
                studentId: 's1',
                studentName: 'Ana',
                status: conflict ? 'unmarked' : 'absent',
              ),
            ],
          );
        }
        if (conflict) {
          throw const AppFailure(
            code: AppFailureCode.conflict,
            message: 'A chamada foi alterada por outra pessoa.',
          );
        }
        return const <String, Object?>{'id': 'ses1', 'revision': 2};
      };
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();
    controller.mark('e1', AttendanceStatus.present);

    final bool saved = await controller.save(finalize: false);

    expect(saved, isFalse);
    expect(controller.hasConflict, isTrue);
    expect(controller.statusOf('e1'), AttendanceStatus.present);
    expect(controller.requestId, isNotNull);

    conflict = false;
    await controller.reloadAfterConflict();

    expect(controller.serverMarks?['e1'], AttendanceStatus.absent);
    expect(controller.statusOf('e1'), AttendanceStatus.present);
  });

  test(
    'a timeout retains the request identity for an explicit retry',
    () async {
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onInvoke = (String operation, JsonMap _) {
          if (operation == 'getSessionAttendance') {
            return view();
          }
          throw const AppFailure(
            code: AppFailureCode.unavailable,
            message: 'Tempo esgotado.',
          );
        };
      final AttendanceController controller = attendanceController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      controller.mark('e1', AttendanceStatus.present);

      final bool first = await controller.save(finalize: false);
      final String? retained = controller.requestId;

      expect(first, isFalse);
      expect(retained, isNotNull);
      expect(controller.statusOf('e1'), AttendanceStatus.present);
      expect(controller.errorMessage, isNotNull);

      await controller.retry(finalize: false);

      final List<JsonMap> payloads = gateway.invocations
          .where(
            (({String operation, JsonMap payload}) call) =>
                call.operation == 'saveAttendance',
          )
          .map((({String operation, JsonMap payload}) call) => call.payload)
          .toList();
      expect(payloads, hasLength(2));
      expect(payloads[0]['requestId'], retained);
      expect(payloads[1]['requestId'], retained);
    },
  );

  test(
    'cancellation sends the canceled status and expected revision',
    () async {
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onInvoke = (String operation, JsonMap _) =>
            operation == 'cancelSession'
            ? const <String, Object?>{'id': 'ses1', 'revision': 2}
            : view(revision: 1, status: 'finalized');
      final AttendanceController controller = attendanceController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      final bool canceled = await controller.cancelSession();

      expect(canceled, isTrue);
      final JsonMap payload = gateway.invocations
          .lastWhere(
            (({String operation, JsonMap payload}) call) =>
                call.operation == 'cancelSession',
          )
          .payload;
      expect(payload['status'], 'canceled');
      expect(payload['expectedRevision'], 1);
    },
  );
}
