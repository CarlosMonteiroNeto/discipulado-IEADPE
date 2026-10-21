import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/ui/class_detail_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/class_enrollment_panel.dart';
import 'package:ieadpe_converts/features/ministry/ui/enrollment_progress_panel.dart';
import 'package:ieadpe_converts/features/ministry/ui/student_detail_page.dart';

const _scope = '33333333-3333-4333-8333-333333333333';
const _otherScope = '99999999-9999-4999-8999-999999999998';
const _studentId = '11111111-1111-4111-8111-111111111111';
const _otherStudentId = '99999999-9999-4999-8999-999999999997';
const _classId = '22222222-2222-4222-8222-222222222222';
const _activeEnrollmentId = '77777777-7777-4777-8777-777777777777';
const _closedEnrollmentId = '88888888-8888-4888-8888-888888888888';
const _actor = '55555555-5555-4555-8555-555555555555';

typedef _HistoryPage = ({List<Map<String, Object?>> items, String? nextCursor});

class _ProgressGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String check) {
    if (check != context) throw const DataFailure('stale');
  }

  final reads = <({String rpc, Map<String, Object?> parameters})>[];
  final history = <String, _HistoryPage>{};
  final progress = <String, Map<String, Object?>>{};
  DataFailure? failProgressOnce;
  DataFailure? failHistoryOnce;
  Completer<Map<String, dynamic>>? delayedProgress;
  String? delayedProgressEnrollmentId;
  Completer<Map<String, dynamic>>? delayedHistory;
  String? delayedHistoryStudentId;
  Completer<Map<String, dynamic>>? delayedMoreHistory;
  String? delayedMoreCursor;
  String rosterName = 'Pessoa Exemplo';

  List<({String rpc, Map<String, Object?> parameters})> get progressReads =>
      reads
          .where((read) => read.rpc == 'ministry_get_enrollment_progress')
          .toList(growable: false);

  Map<String, Object?> _studentDetail(String id, String scope, String name) => {
    'id': id,
    'person_id': null,
    'congregation_id': scope,
    'name': name,
    'normalized_name': name.toLowerCase(),
    'phone_e164': null,
    'birth_date': null,
    'address': null,
    'education': null,
    'marital_status': null,
    'new_convert': false,
    'water_baptized': null,
    'wants_baptism': null,
    'archived_at': null,
    'revision': 2,
    'person_revision': null,
    'link_state': 'unlinked',
    'created_at': '2026-10-18T12:00:00Z',
    'updated_at': '2026-10-18T12:00:00Z',
    'updated_by': null,
  };

  Map<String, dynamic> _rosterResponse() => {
    'items': [
      {
        'student': {
          'id': _studentId,
          'person_id': null,
          'person_revision': null,
          'congregation_id': _scope,
          'name': rosterName,
          'normalized_name': rosterName.toLowerCase(),
          'phone_e164': null,
          'birth_date': null,
          'address': null,
          'education': null,
          'marital_status': null,
          'new_convert': null,
          'water_baptized': null,
          'wants_baptism': null,
          'archived_at': null,
          'revision': 1,
          'created_at': '2026-10-19T00:00:00Z',
          'updated_at': '2026-10-19T00:00:00Z',
          'updated_by': _actor,
        },
        'enrollment': {
          'id': _activeEnrollmentId,
          'congregation_id': _scope,
          'student_id': _studentId,
          'class_id': _classId,
          'start_date': '2026-10-01',
          'end_date': null,
          'status': 'active',
          'revision': 1,
          'created_at': '2026-10-19T00:00:00Z',
          'updated_at': '2026-10-19T00:00:00Z',
          'updated_by': _actor,
        },
      },
    ],
    'next_cursor': null,
  };

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    reads.add((rpc: rpc, parameters: Map.of(parameters)));
    switch (rpc) {
      case 'ministry_get_student':
        final id = parameters['student_id']! as String;
        final scope = parameters['congregation_id']! as String;
        return {
          'student': _studentDetail(
            id,
            scope,
            id == _otherStudentId ? 'Outro Aluno' : 'Ana Silva',
          ),
        };
      case 'ministry_list_student_enrollments':
        final student = parameters['student_id']! as String;
        final cursor = parameters['cursor'] as String?;
        if (delayedHistoryStudentId == student && cursor == null) {
          final pending = delayedHistory;
          delayedHistoryStudentId = null;
          delayedHistory = null;
          if (pending != null) return pending.future;
        }
        if (delayedMoreCursor != null && delayedMoreCursor == cursor) {
          final pending = delayedMoreHistory;
          delayedMoreCursor = null;
          delayedMoreHistory = null;
          if (pending != null) return pending.future;
        }
        final failure = failHistoryOnce;
        if (failure != null) {
          failHistoryOnce = null;
          throw failure;
        }
        final page = history['$student:${cursor ?? 'first'}'];
        if (page == null) {
          throw StateError('Missing history for $student/$cursor');
        }
        return {'items': page.items, 'next_cursor': page.nextCursor};
      case 'ministry_get_enrollment_progress':
        final enrollmentId = parameters['enrollment_id']! as String;
        if (delayedProgressEnrollmentId == enrollmentId) {
          final pending = delayedProgress;
          delayedProgressEnrollmentId = null;
          delayedProgress = null;
          if (pending != null) return pending.future;
        }
        final failure = failProgressOnce;
        if (failure != null) {
          failProgressOnce = null;
          throw failure;
        }
        final value = progress[enrollmentId];
        if (value == null) {
          throw StateError('Missing progress for $enrollmentId');
        }
        return Map<String, dynamic>.of(value);
      case 'ministry_list_class_students':
        return _rosterResponse();
    }
    throw UnimplementedError(rpc);
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) => throw UnimplementedError(table);

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) => throw UnimplementedError(command);

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) => throw UnimplementedError(command);

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) => throw UnimplementedError();
}

Map<String, Object?> _historyItem({
  required String id,
  required String className,
  required String startDate,
  String? endDate,
  required String status,
}) => {
  'id': id,
  'class_id': _classId,
  'class_name': className,
  'start_date': startDate,
  'end_date': endDate,
  'status': status,
  'revision': 1,
};

Map<String, Object?> _progressWire(
  String enrollmentId, {
  required int present,
  required int absent,
  required int excused,
}) {
  final denominator = present + absent;
  return {
    'enrollment_id': enrollmentId,
    'present': present,
    'absent': absent,
    'excused': excused,
    'denominator': denominator,
    'percentage': denominator == 0 ? null : present / denominator,
    'rounded_percentage': denominator == 0
        ? null
        : (present * 100 / denominator).round(),
  };
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _moreHistorySpinner() => find.byWidgetPredicate(
  (widget) =>
      widget is LinearProgressIndicator &&
      widget.semanticsLabel == 'Carregando mais matrículas',
);

void _seedTwoEnrollments(_ProgressGateway gateway) {
  gateway.history['$_studentId:first'] = (
    items: [
      _historyItem(
        id: _activeEnrollmentId,
        className: 'Discipulado Ativo',
        startDate: '2026-03-01',
        status: 'active',
      ),
      _historyItem(
        id: _closedEnrollmentId,
        className: 'Discipulado 2025',
        startDate: '2025-02-01',
        endDate: '2025-12-15',
        status: 'completed',
      ),
    ],
    nextCursor: null,
  );
  gateway.progress[_activeEnrollmentId] = _progressWire(
    _activeEnrollmentId,
    present: 3,
    absent: 1,
    excused: 2,
  );
  gateway.progress[_closedEnrollmentId] = _progressWire(
    _closedEnrollmentId,
    present: 0,
    absent: 0,
    excused: 2,
  );
}

void main() {
  testWidgets(
    'student detail lists active and closed enrollments and loads only the selected progress',
    (tester) async {
      _useDesktopViewport(tester);
      final gateway = _ProgressGateway();
      _seedTwoEnrollments(gateway);

      await tester.pumpWidget(
        MaterialApp(
          home: StudentDetailPage(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            studentId: _studentId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Histórico de matrículas'), findsOneWidget);
      expect(find.text('Discipulado Ativo'), findsOneWidget);
      expect(find.text('Discipulado 2025'), findsOneWidget);
      expect(find.text('Ativa'), findsOneWidget);
      expect(find.text('Concluída'), findsOneWidget);
      expect(gateway.progressReads, isEmpty);

      await tester.tap(
        find.byKey(const Key('enrollment-progress-$_activeEnrollmentId')),
      );
      await tester.pumpAndSettle();

      expect(gateway.progressReads, hasLength(1));
      expect(
        gateway.progressReads.single.parameters['enrollment_id'],
        _activeEnrollmentId,
      );
      expect(
        gateway.progressReads.single.parameters['congregation_id'],
        _scope,
      );
      expect(find.text('Aulas avaliadas: 4'), findsOneWidget);
      expect(find.text('Presenças: 3'), findsOneWidget);
      expect(find.text('Ausências: 1'), findsOneWidget);
      expect(find.text('Justificadas: 2'), findsOneWidget);
      expect(find.text('Aproveitamento: 75%'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('enrollment-progress-$_closedEnrollmentId')),
      );
      await tester.pumpAndSettle();

      expect(gateway.progressReads, hasLength(2));
      expect(
        gateway.progressReads.last.parameters['enrollment_id'],
        _closedEnrollmentId,
      );
      expect(find.text('Sem aulas avaliadas'), findsOneWidget);
      expect(find.textContaining('Aproveitamento:'), findsNothing);
      expect(find.text('Presenças: 3'), findsNothing);
    },
  );

  testWidgets('forbidden progress read is actionable and retryable', (
    tester,
  ) async {
    final gateway = _ProgressGateway()
      ..failProgressOnce = const DataFailure('permission');
    gateway.progress[_activeEnrollmentId] = _progressWire(
      _activeEnrollmentId,
      present: 1,
      absent: 1,
      excused: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnrollmentProgressPanel(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            enrollmentId: _activeEnrollmentId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Seu acesso mudou. Volte e atualize a sessão para ver o progresso.',
      ),
      findsOneWidget,
    );
    final retry = find.byKey(const Key('retry-enrollment-progress'));
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(gateway.progressReads, hasLength(2));
    expect(find.text('Presenças: 1'), findsOneWidget);
    expect(find.text('Aproveitamento: 50%'), findsOneWidget);
  });

  testWidgets(
    'refresh reads persisted progress again instead of incrementing',
    (tester) async {
      final gateway = _ProgressGateway();
      gateway.progress[_activeEnrollmentId] = _progressWire(
        _activeEnrollmentId,
        present: 1,
        absent: 0,
        excused: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnrollmentProgressPanel(
              repository: MinistryRepository(gateway),
              congregationId: _scope,
              enrollmentId: _activeEnrollmentId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Presenças: 1'), findsOneWidget);

      gateway.progress[_activeEnrollmentId] = _progressWire(
        _activeEnrollmentId,
        present: 2,
        absent: 0,
        excused: 1,
      );
      await tester.tap(find.byKey(const Key('refresh-enrollment-progress')));
      await tester.pumpAndSettle();

      expect(gateway.progressReads, hasLength(2));
      expect(find.text('Presenças: 2'), findsOneWidget);
      expect(find.text('Justificadas: 1'), findsOneWidget);
      expect(find.text('Aproveitamento: 100%'), findsOneWidget);
    },
  );

  testWidgets(
    'late progress reply for the previous enrollment or scope is discarded',
    (tester) async {
      final gateway = _ProgressGateway();
      final stale = Completer<Map<String, dynamic>>();
      gateway.delayedProgressEnrollmentId = _activeEnrollmentId;
      gateway.delayedProgress = stale;
      gateway.progress[_closedEnrollmentId] = _progressWire(
        _closedEnrollmentId,
        present: 0,
        absent: 0,
        excused: 0,
      );

      Widget panel(String scope, String enrollmentId) => MaterialApp(
        home: Scaffold(
          body: EnrollmentProgressPanel(
            repository: MinistryRepository(gateway),
            congregationId: scope,
            enrollmentId: enrollmentId,
          ),
        ),
      );

      await tester.pumpWidget(panel(_scope, _activeEnrollmentId));
      await tester.pump();
      expect(find.text('Carregando progresso da matrícula…'), findsOneWidget);

      await tester.pumpWidget(panel(_otherScope, _closedEnrollmentId));
      await tester.pumpAndSettle();
      expect(find.text('Sem aulas avaliadas'), findsOneWidget);

      stale.complete({
        ..._progressWire(
          _activeEnrollmentId,
          present: 9,
          absent: 0,
          excused: 0,
        ),
      });
      await tester.pumpAndSettle();

      expect(
        gateway.progressReads.last.parameters['congregation_id'],
        _otherScope,
      );
      expect(find.text('Presenças: 9'), findsNothing);
      expect(find.text('Sem aulas avaliadas'), findsOneWidget);
    },
  );

  testWidgets(
    'class detail reuses the progress panel for the selected enrollment and returns to the roster',
    (tester) async {
      _useDesktopViewport(tester);
      final gateway = _ProgressGateway();
      gateway.progress[_activeEnrollmentId] = _progressWire(
        _activeEnrollmentId,
        present: 2,
        absent: 2,
        excused: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClassDetailPage(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classSummary: const MinistryClassSummary(
              id: _classId,
              name: 'Fundamentos',
              status: ClassStatus.active,
              startDate: '2026-10-01',
              endDate: null,
              revision: 1,
              teacherContactId: null,
            ),
            onChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pessoa Exemplo'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('class-enrollment-progress-$_activeEnrollmentId')),
      );
      await tester.pumpAndSettle();

      expect(gateway.progressReads, hasLength(1));
      expect(gateway.progressReads.single.parameters, {
        'congregation_id': _scope,
        'enrollment_id': _activeEnrollmentId,
      });
      expect(find.text('Progresso da matrícula selecionada'), findsOneWidget);
      expect(find.text('Aproveitamento: 50%'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('close-class-enrollment-progress')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pessoa Exemplo'), findsOneWidget);
      expect(find.text('Progresso da matrícula selecionada'), findsNothing);
    },
  );

  testWidgets('student history pagination appends the next bounded page', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    final gateway = _ProgressGateway();
    gateway.history['$_studentId:first'] = (
      items: [
        _historyItem(
          id: _activeEnrollmentId,
          className: 'Discipulado Ativo',
          startDate: '2026-03-01',
          status: 'active',
        ),
      ],
      nextCursor: 'cursor-1',
    );
    gateway.history['$_studentId:cursor-1'] = (
      items: [
        _historyItem(
          id: _closedEnrollmentId,
          className: 'Discipulado 2025',
          startDate: '2025-02-01',
          endDate: '2025-12-15',
          status: 'withdrawn',
        ),
      ],
      nextCursor: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailPage(
          repository: MinistryRepository(gateway),
          congregationId: _scope,
          studentId: _studentId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Discipulado Ativo'), findsOneWidget);
    expect(find.text('Discipulado 2025'), findsNothing);

    final loadMore = find.byKey(const Key('load-more-enrollments'));
    expect(loadMore, findsOneWidget);
    await tester.tap(loadMore);
    await tester.pumpAndSettle();

    final pageReads = gateway.reads
        .where((read) => read.rpc == 'ministry_list_student_enrollments')
        .toList(growable: false);
    expect(pageReads, hasLength(2));
    expect(pageReads.last.parameters['cursor'], 'cursor-1');
    expect(pageReads.last.parameters['limit'], 50);
    expect(find.text('Discipulado 2025'), findsOneWidget);
    expect(find.text('Desistência'), findsOneWidget);
    expect(find.byKey(const Key('load-more-enrollments')), findsNothing);
  });

  testWidgets(
    'first-page refresh discards pending pagination and clears loading state',
    (tester) async {
      _useDesktopViewport(tester);
      final gateway = _ProgressGateway();
      gateway.history['$_studentId:first'] = (
        items: [
          _historyItem(
            id: _activeEnrollmentId,
            className: 'Discipulado Ativo',
            startDate: '2026-03-01',
            status: 'active',
          ),
        ],
        nextCursor: 'cursor-1',
      );
      gateway.history['$_studentId:cursor-1'] = (
        items: [
          _historyItem(
            id: _closedEnrollmentId,
            className: 'Discipulado Antigo',
            startDate: '2025-02-01',
            status: 'completed',
          ),
        ],
        nextCursor: null,
      );
      final staleMore = Completer<Map<String, dynamic>>();
      gateway.delayedMoreCursor = 'cursor-1';
      gateway.delayedMoreHistory = staleMore;

      await tester.pumpWidget(
        MaterialApp(
          home: StudentDetailPage(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            studentId: _studentId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('load-more-enrollments')));
      await tester.pump();
      expect(_moreHistorySpinner(), findsOneWidget);

      gateway.history['$_studentId:first'] = (
        items: [
          _historyItem(
            id: _activeEnrollmentId,
            className: 'Discipulado Ativo',
            startDate: '2026-03-01',
            status: 'active',
          ),
          _historyItem(
            id: _closedEnrollmentId,
            className: 'Discipulado Atualizado',
            startDate: '2026-01-01',
            status: 'active',
          ),
        ],
        nextCursor: 'cursor-2',
      );
      await tester.tap(find.byKey(const Key('refresh-enrollment-history')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('Discipulado Atualizado'), findsOneWidget);
      expect(_moreHistorySpinner(), findsNothing);
      final loadMore = find.byKey(const Key('load-more-enrollments'));
      expect(loadMore, findsOneWidget);
      expect(tester.widget<OutlinedButton>(loadMore).onPressed, isNotNull);

      staleMore.complete({
        'items': [
          _historyItem(
            id: _closedEnrollmentId,
            className: 'Discipulado Antigo',
            startDate: '2025-02-01',
            status: 'completed',
          ),
        ],
        'next_cursor': null,
      });
      await tester.pumpAndSettle();

      expect(find.text('Discipulado Antigo'), findsNothing);
      expect(find.text('Discipulado Atualizado'), findsOneWidget);
      expect(_moreHistorySpinner(), findsNothing);
      expect(tester.widget<OutlinedButton>(loadMore).onPressed, isNotNull);
    },
  );

  testWidgets(
    'retry after a failed first page request reloads the first page',
    (tester) async {
      _useDesktopViewport(tester);
      final gateway = _ProgressGateway();
      gateway.history['$_studentId:first'] = (
        items: [
          _historyItem(
            id: _activeEnrollmentId,
            className: 'Discipulado Ativo',
            startDate: '2026-03-01',
            status: 'active',
          ),
        ],
        nextCursor: 'cursor-1',
      );
      gateway.history['$_studentId:cursor-1'] = (
        items: [
          _historyItem(
            id: _closedEnrollmentId,
            className: 'Página Indevida',
            startDate: '2025-02-01',
            status: 'completed',
          ),
        ],
        nextCursor: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentDetailPage(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            studentId: _studentId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      gateway.failHistoryOnce = const DataFailure('stale');
      await tester.tap(find.byKey(const Key('refresh-enrollment-history')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Sua sessão ou congregação mudou. Atualize a página para continuar.',
        ),
        findsOneWidget,
      );

      gateway.history['$_studentId:first'] = (
        items: [
          _historyItem(
            id: _activeEnrollmentId,
            className: 'Discipulado Ativo',
            startDate: '2026-03-01',
            status: 'active',
          ),
          _historyItem(
            id: _closedEnrollmentId,
            className: 'Discipulado Atualizado',
            startDate: '2026-01-01',
            status: 'active',
          ),
        ],
        nextCursor: 'cursor-2',
      );
      await tester.tap(find.byKey(const Key('retry-enrollment-history')));
      await tester.pumpAndSettle();

      final pageReads = gateway.reads
          .where((read) => read.rpc == 'ministry_list_student_enrollments')
          .toList(growable: false);
      expect(pageReads.last.parameters['cursor'], isNull);
      expect(find.text('Discipulado Atualizado'), findsOneWidget);
      expect(find.text('Página Indevida'), findsNothing);
    },
  );

  testWidgets('retry after a failed pagination reuses its exact cursor', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    final gateway = _ProgressGateway();
    gateway.history['$_studentId:first'] = (
      items: [
        _historyItem(
          id: _activeEnrollmentId,
          className: 'Discipulado Ativo',
          startDate: '2026-03-01',
          status: 'active',
        ),
      ],
      nextCursor: 'cursor-1',
    );
    gateway.history['$_studentId:cursor-1'] = (
      items: [
        _historyItem(
          id: _closedEnrollmentId,
          className: 'Discipulado Segunda Página',
          startDate: '2025-02-01',
          status: 'completed',
        ),
      ],
      nextCursor: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailPage(
          repository: MinistryRepository(gateway),
          congregationId: _scope,
          studentId: _studentId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    gateway.failHistoryOnce = const DataFailure('unavailable');
    await tester.tap(find.byKey(const Key('load-more-enrollments')));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar o histórico de matrículas.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('retry-enrollment-history')));
    await tester.pumpAndSettle();

    final pageReads = gateway.reads
        .where((read) => read.rpc == 'ministry_list_student_enrollments')
        .toList(growable: false);
    expect(pageReads.last.parameters['cursor'], 'cursor-1');
    expect(
      pageReads.where((read) => read.parameters['cursor'] == null),
      hasLength(1),
    );
    expect(find.text('Discipulado Segunda Página'), findsOneWidget);
  });

  testWidgets('student history empty state is explicit and refreshable', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    final gateway = _ProgressGateway();
    gateway.history['$_studentId:first'] = (items: const [], nextCursor: null);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailPage(
          repository: MinistryRepository(gateway),
          congregationId: _scope,
          studentId: _studentId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhuma matrícula registrada para este aluno.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('refresh-enrollment-history')), findsOneWidget);
  });

  testWidgets('stale student history is actionable and retryable', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    final gateway = _ProgressGateway()
      ..failHistoryOnce = const DataFailure('stale');
    gateway.history['$_studentId:first'] = (
      items: [
        _historyItem(
          id: _activeEnrollmentId,
          className: 'Discipulado Ativo',
          startDate: '2026-03-01',
          status: 'active',
        ),
      ],
      nextCursor: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailPage(
          repository: MinistryRepository(gateway),
          congregationId: _scope,
          studentId: _studentId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Sua sessão ou congregação mudou. Atualize a página para continuar.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('retry-enrollment-history')));
    await tester.pumpAndSettle();

    expect(find.text('Discipulado Ativo'), findsOneWidget);
  });

  testWidgets(
    'class enrollment reload refreshes the selected persisted progress',
    (tester) async {
      final gateway = _ProgressGateway();
      gateway.progress[_activeEnrollmentId] = _progressWire(
        _activeEnrollmentId,
        present: 1,
        absent: 0,
        excused: 0,
      );

      Widget panel(int reloadToken) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClassEnrollmentPanel(
              key: const ValueKey('class-enrollment-panel'),
              repository: MinistryRepository(gateway),
              congregationId: _scope,
              classId: _classId,
              classStartDate: '2026-10-01',
              classEndDate: null,
              reloadToken: reloadToken,
              onChanged: () {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(panel(0));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('class-enrollment-progress-$_activeEnrollmentId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Presenças: 1'), findsOneWidget);

      gateway.progress[_activeEnrollmentId] = _progressWire(
        _activeEnrollmentId,
        present: 2,
        absent: 0,
        excused: 1,
      );
      await tester.pumpWidget(panel(1));
      await tester.pumpAndSettle();

      expect(gateway.progressReads, hasLength(2));
      expect(find.text('Presenças: 2'), findsOneWidget);
      expect(find.text('Justificadas: 1'), findsOneWidget);
    },
  );

  testWidgets('late history page from a previous student is discarded', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    final gateway = _ProgressGateway();
    final staleHistory = Completer<Map<String, dynamic>>();
    gateway.delayedHistoryStudentId = _studentId;
    gateway.delayedHistory = staleHistory;
    gateway.history['$_otherStudentId:first'] = (
      items: [
        _historyItem(
          id: _closedEnrollmentId,
          className: 'Discipulado Outro',
          startDate: '2026-01-01',
          status: 'active',
        ),
      ],
      nextCursor: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailPage(
          repository: MinistryRepository(gateway),
          congregationId: _scope,
          studentId: _studentId,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      gateway.reads.any(
        (read) =>
            read.rpc == 'ministry_list_student_enrollments' &&
            read.parameters['student_id'] == _studentId,
      ),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailPage(
          repository: MinistryRepository(gateway),
          congregationId: _scope,
          studentId: _otherStudentId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Outro Aluno'), findsWidgets);
    expect(find.text('Discipulado Outro'), findsOneWidget);

    staleHistory.complete({
      'items': [
        _historyItem(
          id: _activeEnrollmentId,
          className: 'Discipulado Antigo',
          startDate: '2026-02-01',
          status: 'active',
        ),
      ],
      'next_cursor': null,
    });
    await tester.pumpAndSettle();

    expect(find.text('Discipulado Antigo'), findsNothing);
    expect(find.text('Discipulado Outro'), findsOneWidget);
  });

  testWidgets(
    'class roster progress controls remain usable at 360 width with 200% text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = _ProgressGateway();
      gateway.progress[_activeEnrollmentId] = _progressWire(
        _activeEnrollmentId,
        present: 1,
        absent: 0,
        excused: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ClassEnrollmentPanel(
                  repository: MinistryRepository(gateway),
                  congregationId: _scope,
                  classId: _classId,
                  classStartDate: '2026-10-01',
                  classEndDate: null,
                  onChanged: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final progressButton = find.byKey(
        const Key('class-enrollment-progress-$_activeEnrollmentId'),
      );
      await tester.ensureVisible(progressButton);
      await tester.tap(progressButton);
      await tester.pumpAndSettle();

      expect(find.text('Aproveitamento: 100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('progress panel remains usable at 360 width with 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _ProgressGateway();
    gateway.progress[_activeEnrollmentId] = _progressWire(
      _activeEnrollmentId,
      present: 12,
      absent: 3,
      excused: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: EnrollmentProgressPanel(
                repository: MinistryRepository(gateway),
                congregationId: _scope,
                enrollmentId: _activeEnrollmentId,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Presenças: 12'), findsOneWidget);
    expect(find.text('Aproveitamento: 80%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
