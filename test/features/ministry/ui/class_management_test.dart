import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/ui/class_detail_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/class_form.dart';
import 'package:ieadpe_converts/features/ministry/ui/classes_page.dart';

const _scope = '33333333-3333-4333-8333-333333333333';
const _otherScope = '77777777-7777-4777-8777-777777777777';
const _classId = '22222222-2222-4222-8222-222222222222';
const _teacherId = '44444444-4444-4444-8444-444444444444';
const _archivedTeacherId = '55555555-5555-4555-8555-555555555555';
const _otherTeacherId = '66666666-6666-4666-8666-666666666666';
const _operationId = '88888888-8888-4888-8888-888888888888';

class _ClassGateway implements ReadRpcGateway, MinistryCommandGateway {
  _ClassGateway();

  @override
  final boundary = ProtectedDataBoundary();

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String context) {
    if (context != this.context) throw const DataFailure('stale');
  }

  final readRequests = <({String rpc, Map<String, Object?> parameters})>[];
  final commands =
      <({String name, String operationId, Map<String, Object?> payload})>[];
  DataFailure? teacherReadFailure;
  DataFailure? commandFailure;
  int commandRevision = 1;

  final teacherChoices = <Map<String, dynamic>>[
    _directoryTeacher(_teacherId, 'Ana Professora', _scope),
    _directoryTeacher(
      _archivedTeacherId,
      'Professora Arquivada',
      _scope,
      archivedAt: '2026-09-01T00:00:00Z',
    ),
    _directoryTeacher(
      '99999999-9999-4999-8999-999999999999',
      'Contato sem função de professor',
      _scope,
      role: RoleCode.campaignLeader.wire,
    ),
    _directoryTeacher(
      _otherTeacherId,
      'Professor de outra congregação',
      _otherScope,
    ),
  ];

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => throw UnimplementedError(table);

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError(command);

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    readRequests.add((rpc: rpc, parameters: Map.of(parameters)));
    if (rpc == 'ministry_list_directory') {
      return {'items': teacherChoices, 'next_cursor': null};
    }
    if (rpc == 'ministry_list_classes') {
      return {
        'items': [
          {
            'id': _classId,
            'name': 'Fundamentos',
            'status': 'active',
            'start_date': '2026-10-01',
            'end_date': null,
            'revision': 1,
            'teacher_contact_id': _teacherId,
          },
        ],
        'next_cursor': null,
      };
    }
    if (rpc == 'ministry_get_teacher_contact') {
      if (teacherReadFailure case final failure?) throw failure;
      if (parameters['contact_id'] == _teacherId) {
        return {
          'contact': {
            'id': _teacherId,
            'congregation_id': _scope,
            'name': 'Ana Professora',
            'phone_e164': null,
            'birth_date': null,
            'revision': 3,
          },
        };
      }
      return {
        'contact': {
          'id': _otherTeacherId,
          'congregation_id': _otherScope,
          'name': 'Professor de outra congregação',
          'phone_e164': null,
          'birth_date': null,
          'revision': 2,
        },
      };
    }
    throw UnimplementedError(rpc);
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String name,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    if (commandFailure case final failure?) throw failure;
    commands.add((
      name: name,
      operationId: operationId,
      payload: Map.of(payload),
    ));
    return {'id': payload['id'], 'revision': commandRevision};
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

Map<String, dynamic> _directoryTeacher(
  String id,
  String name,
  String congregationId, {
  String role = 'teacher',
  String? archivedAt,
}) => {
  'id': id,
  'name': name,
  'normalized_name': name.toLowerCase(),
  'scope': 'congregation',
  'congregation_id': congregationId,
  'role_code': role,
  'phone_e164': null,
  'birth_date': null,
  'email': null,
  'archived_at': archivedAt,
  'revision': 1,
  'user_access_id': null,
};

MinistryClassSummary _classSummary({
  ClassStatus status = ClassStatus.active,
  int revision = 1,
  String? teacherContactId,
}) => MinistryClassSummary(
  id: _classId,
  name: 'Fundamentos',
  status: status,
  startDate: '2026-10-01',
  endDate: null,
  revision: revision,
  teacherContactId: teacherContactId,
);

void main() {
  group('class repository commands', () {
    test('creates and edits a class with the selected local teacher', () async {
      final gateway = _ClassGateway();
      final repository = MinistryRepository(gateway);
      final startDate = CalendarDate(2026, 10, 1);
      final endDate = CalendarDate(2026, 12, 31);

      final created = await repository.saveClass(
        operationId: _operationId,
        id: _classId,
        congregationId: _scope,
        name: 'Fundamentos',
        teacherContactId: _teacherId,
        startDate: startDate,
        endDate: endDate,
      );
      expect(created.id, _classId);
      expect(created.revision, 1);
      expect(gateway.commands.single.name, 'save_class');
      expect(gateway.commands.single.operationId, _operationId);
      expect(gateway.commands.single.payload, {
        'id': _classId,
        'congregation_id': _scope,
        'name': 'Fundamentos',
        'teacher_contact_id': _teacherId,
        'start_date': '2026-10-01',
        'end_date': '2026-12-31',
      });
      expect(gateway.readRequests.single.rpc, 'ministry_get_teacher_contact');
      expect(gateway.readRequests.single.parameters, {
        'congregation_id': _scope,
        'contact_id': _teacherId,
      });

      gateway.commandRevision = 5;
      final edited = await repository.saveClass(
        operationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        id: _classId,
        congregationId: _scope,
        name: 'Fundamentos II',
        teacherContactId: _teacherId,
        startDate: startDate,
        endDate: endDate,
        expectedRevision: 4,
      );
      expect(edited.revision, 5);
      expect(gateway.commands.last.payload['expected_revision'], 4);
      expect(gateway.commands.last.payload['congregation_id'], _scope);
      expect(gateway.commands.last.payload['teacher_contact_id'], _teacherId);
    });

    test('rejects a teacher from another congregation before save', () async {
      final gateway = _ClassGateway()
        ..teacherReadFailure = const DataFailure('permission');
      final repository = MinistryRepository(gateway);

      await expectLater(
        repository.saveClass(
          operationId: _operationId,
          id: _classId,
          congregationId: _scope,
          name: 'Fundamentos',
          teacherContactId: _otherTeacherId,
          startDate: CalendarDate(2026, 10, 1),
          endDate: null,
        ),
        throwsA(isA<DataFailure>()),
      );
      expect(gateway.commands, isEmpty);
    });

    test(
      'archive is a revisioned status change that preserves class history',
      () async {
        final gateway = _ClassGateway()..commandRevision = 6;
        final repository = MinistryRepository(gateway);

        final result = await repository.setClassStatus(
          operationId: _operationId,
          id: _classId,
          congregationId: _scope,
          currentStatus: ClassStatus.completed,
          status: ClassStatus.archived,
          expectedRevision: 5,
        );

        expect(result.revision, 6);
        expect(gateway.commands, hasLength(1));
        expect(gateway.commands.single.name, 'set_class_status');
        expect(gateway.commands.single.payload, {
          'id': _classId,
          'congregation_id': _scope,
          'status': 'archived',
          'expected_revision': 5,
        });
        expect(
          gateway.commands.any((command) => command.name.contains('delete')),
          isFalse,
        );
        expect(gateway.readRequests, isEmpty);
      },
    );

    test(
      'stale class revision is reported without changing the revision',
      () async {
        final gateway = _ClassGateway()
          ..commandFailure = const DataFailure('stale_revision');
        final repository = MinistryRepository(gateway);

        await expectLater(
          repository.saveClass(
            operationId: _operationId,
            id: _classId,
            congregationId: _scope,
            name: 'Fundamentos',
            teacherContactId: null,
            startDate: CalendarDate(2026, 10, 1),
            endDate: null,
            expectedRevision: 2,
          ),
          throwsA(isA<DataFailure>()),
        );
        expect(gateway.commands, hasLength(0));
      },
    );

    test(
      'completed classes cannot be reopened through a status command',
      () async {
        final gateway = _ClassGateway();
        final repository = MinistryRepository(gateway);

        await expectLater(
          repository.setClassStatus(
            operationId: _operationId,
            id: _classId,
            congregationId: _scope,
            currentStatus: ClassStatus.completed,
            status: ClassStatus.active,
            expectedRevision: 4,
          ),
          throwsA(isA<DataFailure>()),
        );
        expect(gateway.commands, isEmpty);
      },
    );
  });

  testWidgets(
    'class form offers only active local teachers and validates dates',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = _ClassGateway();
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ClassForm(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            onSaved: (_) => saved = true,
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final helperText = tester.renderObject<RenderParagraph>(
        find.text('Apenas professores ativos desta congregação.'),
      );
      expect(helperText.maxLines, 2);

      expect(gateway.readRequests.single.rpc, 'ministry_list_directory');
      expect(gateway.readRequests.single.parameters, {
        'scope': 'congregation',
        'congregation_id': _scope,
        'role_code': 'teacher',
        'name_prefix': null,
        'limit': 100,
        'cursor': null,
      });
      await tester.tap(find.byKey(const Key('class-teacher-dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Ana Professora'), findsOneWidget);
      expect(find.text('Professora Arquivada'), findsNothing);
      expect(find.text('Contato sem função de professor'), findsNothing);
      expect(find.text('Professor de outra congregação'), findsNothing);
      await tester.tap(find.text('Ana Professora'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('class-name')),
        'Fundamentos',
      );
      await tester.enterText(
        find.byKey(const Key('class-start-date')),
        '2026-10-01',
      );
      await tester.enterText(
        find.byKey(const Key('class-end-date')),
        '2026-09-30',
      );
      await tester.tap(find.text('Salvar turma'));
      await tester.pumpAndSettle();
      expect(gateway.commands, isEmpty);
      expect(
        find.text(
          'A data de término deve ser igual ou posterior à data de início.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('class-end-date')),
        '2026-12-31',
      );
      await tester.tap(find.text('Salvar turma'));
      await tester.pumpAndSettle();

      expect(saved, isTrue);
      expect(gateway.commands.single.name, 'save_class');
      expect(gateway.commands.single.payload['congregation_id'], _scope);
      expect(gateway.commands.single.payload['teacher_contact_id'], _teacherId);
      expect(gateway.commands.single.payload['start_date'], '2026-10-01');
      expect(gateway.commands.single.payload['end_date'], '2026-12-31');
    },
  );

  testWidgets('classes page creates and opens class details', (tester) async {
    final gateway = _ClassGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ClassesPage(
          repository: MinistryBrowserRepository(gateway),
          congregationId: _scope,
          onOpenAttendance: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nova turma'), findsOneWidget);
    await tester.tap(find.text('Fundamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da turma'), findsOneWidget);
    expect(find.text('Ana Professora'), findsOneWidget);
    expect(find.text('Editar turma'), findsOneWidget);
  });

  testWidgets(
    'archiving from class details retains the class in the detail view',
    (tester) async {
      final gateway = _ClassGateway()..commandRevision = 5;
      await tester.pumpWidget(
        MaterialApp(
          home: ClassDetailPage(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classSummary: _classSummary(
              status: ClassStatus.completed,
              revision: 4,
            ),
            onOpenAttendance: () {},
            onChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Arquivar turma'));
      await tester.pumpAndSettle();
      expect(
        find.text('Os registros e o histórico da turma serão mantidos.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirmar arquivamento'));
      await tester.pumpAndSettle();

      expect(gateway.commands.single.name, 'set_class_status');
      expect(gateway.commands.single.payload['id'], _classId);
      expect(gateway.commands.single.payload['expected_revision'], 4);
      expect(find.text('Fundamentos'), findsOneWidget);
      expect(find.text('Arquivada'), findsWidgets);
    },
  );
}
