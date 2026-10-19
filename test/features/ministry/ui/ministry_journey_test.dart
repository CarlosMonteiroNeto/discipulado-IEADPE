import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_handoff_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/ui/convert_handoff_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/attendance_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/classes_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/ministry_home_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/students_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/team_page.dart';

const _scope = '33333333-3333-4333-8333-333333333333';
const _convert = '11111111-1111-4111-8111-111111111111';
const _student = '22222222-2222-4222-8222-222222222222';
const _classId = '55555555-5555-4555-8555-555555555555';
const _person = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _convert2 = '77777777-7777-4777-8777-777777777777';
const _candidate2 = '88888888-8888-4888-8888-888888888888';
const _sessionId = '99999999-9999-4999-8999-999999999999';

class _Gateway
    implements ReadRpcGateway, HandoffCommandGateway, MinistryCommandGateway {
  final boundaryValue = ProtectedDataBoundary();
  final List<String> operationIds = [];
  final List<Map<String, Object?>> enrollmentPayloads = [];
  int referralReads = 0;
  int promotions = 0;
  int candidateReads = 0;
  int classReads = 0;
  int enrollments = 0;
  bool pagingEnabled = false;
  bool failCandidateRead = false;
  bool failEnrollmentOnce = false;
  bool failFirstPromotion = true;
  List<Map<String, dynamic>> studentRows = const [];
  Completer<Map<String, dynamic>>? promotionCompleter;
  @override
  ProtectedDataBoundary get boundary => boundaryValue;
  @override
  String get context => 'session';
  @override
  void ensureCurrent(String context) {
    if (context != 'session') throw const DataFailure('stale');
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => [];
  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    if (rpc == 'ministry_list_convert_referrals') {
      referralReads++;
      if (pagingEnabled && parameters['cursor'] == 'referral-2') {
        return {
          'items': [
            {
              'convert_id': _convert2,
              'congregation_id': _scope,
              'name': 'Bia Lima',
              'phone': null,
              'address': null,
              'conversion_date': '2026-10-02',
            },
          ],
          'next_cursor': null,
        };
      }
      return {
        'items': [
          {
            'convert_id': _convert,
            'congregation_id': _scope,
            'name': 'Ana Maria',
            'phone': null,
            'address': 'Rua A',
            'conversion_date': '2026-10-01',
          },
        ],
        'next_cursor': pagingEnabled ? 'referral-2' : null,
      };
    }
    if (rpc == 'ministry_list_classes') {
      classReads++;
      if (pagingEnabled && parameters['cursor'] == 'classes-2') {
        return {
          'items': [
            {
              'id': _convert2,
              'name': 'Vida Cristã',
              'status': 'active',
              'start_date': '2026-10-02',
              'end_date': null,
              'revision': 1,
            },
          ],
          'next_cursor': null,
        };
      }
      return {
        'items': [
          {
            'id': _classId,
            'name': 'Fundamentos',
            'status': 'active',
            'start_date': '2026-10-01',
            'end_date': null,
            'revision': 1,
          },
        ],
        'next_cursor': pagingEnabled ? 'classes-2' : null,
      };
    }
    if (rpc == 'ministry_list_convert_student_candidates') {
      candidateReads++;
      if (failCandidateRead) {
        failCandidateRead = false;
        throw const DataFailure('unavailable');
      }
      if (pagingEnabled && parameters['cursor'] == 'candidates-2') {
        return {
          'items': [
            {
              'student_id': _candidate2,
              'name': 'Ana Maria Souza',
              'phone': null,
              'address': null,
            },
          ],
          'next_cursor': null,
        };
      }
      return {
        'items': [
          {
            'student_id': _student,
            'name': 'Ana Maria Silva',
            'phone': '+5511999990000',
            'address': {
              'street': 'Rua B',
              'district': null,
              'city': null,
              'postal_code': null,
              'state_code': null,
            },
          },
        ],
        'next_cursor': pagingEnabled ? 'candidates-2' : null,
      };
    }
    if (rpc == 'ministry_get_overview') {
      return {
        'students': 1,
        'classes': 1,
        'open_sessions': 0,
        'through_date': '2026-10-01',
      };
    }
    if (rpc == 'ministry_list_students') {
      return {'items': studentRows, 'next_cursor': null};
    }
    if (rpc == 'ministry_list_directory') {
      return {'items': [], 'next_cursor': null};
    }
    if (rpc == 'ministry_list_pending_sessions') {
      if (!pagingEnabled) return {'items': [], 'next_cursor': null};
      if (parameters['cursor'] == 'sessions-2') {
        return {
          'items': [
            {
              'id': _sessionId,
              'class_id': _classId,
              'class_name': 'Fundamentos avançados',
              'congregation_id': _scope,
              'date': '2026-10-02',
              'topic': null,
              'status': 'open',
            },
          ],
          'next_cursor': null,
        };
      }
      return {
        'items': [
          {
            'id': _classId,
            'class_id': _classId,
            'class_name': 'Fundamentos',
            'congregation_id': _scope,
            'date': '2026-10-01',
            'topic': null,
            'status': 'open',
          },
        ],
        'next_cursor': 'sessions-2',
      };
    }
    if (rpc == 'ministry_get_session_attendance') {
      return {
        'session': {
          'id': parameters['session_id'],
          'congregation_id': _scope,
          'revision': 1,
          'created_at': '2026-10-01T00:00:00Z',
          'updated_at': '2026-10-01T00:00:00Z',
          'updated_by': _student,
          'class_id': _classId,
          'date': '2026-10-01',
          'topic': null,
          'status': 'open',
          'roster_frozen': true,
          'lesson_index': null,
          'lesson_part': null,
          'lesson_finished': false,
        },
        'roster': [
          {
            'enrollment_id': _sessionId,
            'student_id': _student,
            'student_name':
                'Alexandre dos Santos de Albuquerque da Silva e Oliveira',
            'status': 'unmarked',
          },
        ],
      };
    }
    throw StateError('Unexpected read $rpc');
  }

  @override
  Future<Map<String, dynamic>> promoteConvertToStudent(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    operationIds.add(operationId);
    promotions++;
    if (promotionCompleter != null) return promotionCompleter!.future;
    if (failFirstPromotion && promotions == 1) {
      throw const DataFailure('unavailable');
    }
    return {
      'convert_id': _convert,
      'student_id': _student,
      'congregation_id': _scope,
      'status': 'linked',
    };
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    expect(command, 'enroll_student');
    enrollments++;
    if (failEnrollmentOnce) {
      failEnrollmentOnce = false;
      throw const DataFailure('unavailable');
    }
    enrollmentPayloads.add(Map.of(payload));
    return {'id': payload['id'], 'revision': 1};
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => {
    'student_id': payload['student_id'],
    'person_id': payload['person_id'],
    'student_revision': (payload['expected_student_revision'] as int) + 1,
    'person_revision': payload['expected_person_revision'],
  };

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(
  _Gateway gateway, {
  required bool authorized,
  required Size size,
  double textScale = 1,
  bool reducedMotion = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reducedMotion,
    ),
    child: ConvertHandoffPage(
      congregationId: _scope,
      canPromote: authorized,
      handoff: MinistryHandoffRepository(gateway),
      browser: MinistryBrowserRepository(gateway),
      ministry: MinistryRepository(gateway),
      createOperationId: () => '66666666-6666-4666-8666-666666666666',
    ),
  ),
);

void main() {
  testWidgets('student browser labels canonical link state safely', (
    tester,
  ) async {
    final gateway = _Gateway()
      ..studentRows = [
        {
          'id': _student,
          'person_id': _person,
          'congregation_id': _scope,
          'name': 'Ana Silva',
          'phone': '+5511999990000',
          'birth_date': null,
          'address': null,
          'education': null,
          'marital_status': null,
          'new_convert': null,
          'water_baptized': null,
          'wants_baptism': null,
          'archived_at': null,
          'revision': 5,
          'person_revision': 2,
          'link_state': 'linked',
        },
        {
          'id': _candidate2,
          'person_id': null,
          'congregation_id': _scope,
          'name': 'Registro legado',
          'phone': null,
          'birth_date': null,
          'address': null,
          'education': null,
          'marital_status': null,
          'new_convert': null,
          'water_baptized': null,
          'wants_baptism': null,
          'archived_at': null,
          'revision': 1,
          'person_revision': null,
          'link_state': 'unlinked',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: StudentsPage(
          repository: MinistryBrowserRepository(gateway),
          congregationId: _scope,
          onOpenHandoff: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identidade canônica vinculada'), findsOneWidget);
    expect(find.text('Identidade pendente de revisão'), findsOneWidget);
    expect(find.text('Vinculado ao cadastro de convertidos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'permission denial does not load referral data or expose actions',
    (tester) async {
      final gateway = _Gateway();
      await tester.pumpWidget(
        _app(gateway, authorized: false, size: const Size(360, 800)),
      );
      expect(gateway.referralReads, 0);
      expect(find.text('Ana Maria'), findsNothing);
      expect(find.text('Encaminhar para o discipulado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'promotion retry reuses operation ID and enrollment remains explicit',
    (tester) async {
      final gateway = _Gateway();
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          gateway,
          authorized: true,
          size: const Size(360, 800),
          textScale: 1,
          reducedMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.referralReads, 1);
      final referralTile = find.byKey(
        const Key('handoff-referral-11111111-1111-4111-8111-111111111111'),
        skipOffstage: false,
      );
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Revisar Ana Maria'), findsOneWidget);
      semantics.dispose();
      await tester.ensureVisible(referralTile);
      await tester.pumpAndSettle();
      await tester.tap(referralTile);
      await tester.pumpAndSettle();
      final create = find.text(
        'Criar aluno a partir desta referência',
        skipOffstage: false,
      );
      await tester.scrollUntilVisible(
        create,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('código de operação foram mantidos'),
        findsOneWidget,
      );
      expect(find.text('Vínculo confirmado.'), findsNothing);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(gateway.operationIds, hasLength(2));
      expect(gateway.operationIds[0], gateway.operationIds[1]);
      expect(find.textContaining('Vínculo confirmado'), findsOneWidget);
      expect(gateway.enrollmentPayloads, isEmpty);

      final classSelect = find.byKey(const Key('handoff-class-select'));
      await _dragPageUntilHitTestable(tester, classSelect);
      await tester.tap(classSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundamentos').last);
      await tester.pumpAndSettle();
      final enroll = find.text('Matricular aluno');
      await tester.scrollUntilVisible(
        enroll,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(enroll);
      await tester.pumpAndSettle();
      expect(gateway.enrollmentPayloads, hasLength(1));
      expect(gateway.enrollmentPayloads.single['student_id'], _student);
      expect(gateway.enrollmentPayloads.single['class_id'], _classId);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review layout adapts at desktop, tablet and phone widths', (
    tester,
  ) async {
    final gateway = _Gateway();
    for (final size in [
      const Size(360, 800),
      const Size(768, 900),
      const Size(1440, 1000),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(gateway, authorized: true, size: size));
      await tester.pumpAndSettle();
      expect(find.text('Encaminhar para o discipulado'), findsOneWidget);
      expect(_hasHorizontalOverflow(tester), isFalse);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'review supports keyboard focus and 200 percent text without overflow',
    (tester) async {
      final gateway = _Gateway();
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        _app(
          gateway,
          authorized: true,
          size: const Size(360, 800),
          textScale: 2,
          reducedMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(FocusManager.instance.primaryFocus!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('candidate lookup retry never promotes', (tester) async {
    final gateway = _Gateway()..failCandidateRead = true;
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(gateway, authorized: true, size: const Size(768, 900)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handoff-referral-$_convert')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.tap(find.text('Buscar possíveis alunos'));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(
            find
                .bySemanticsLabel(
                  'Não foi possível buscar alunos. Revise a conexão e tente novamente.',
                )
                .first,
          )
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    semantics.dispose();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(gateway.candidateReads, 2);
    expect(gateway.promotions, 0);
  });

  testWidgets('promotion retry does not repeat a failed enrollment', (
    tester,
  ) async {
    final gateway = _Gateway()
      ..failFirstPromotion = false
      ..failEnrollmentOnce = true;
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(gateway, authorized: true, size: const Size(768, 900)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handoff-referral-$_convert')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar aluno a partir desta referência'));
    await tester.pumpAndSettle();
    final classSelect = find.byKey(const Key('handoff-class-select'));
    await _dragPageUntilHitTestable(tester, classSelect);
    await tester.tap(classSelect);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fundamentos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matricular aluno'));
    await tester.pumpAndSettle();
    expect(gateway.promotions, 1);
    expect(gateway.enrollments, 1);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(gateway.promotions, 1);
    expect(gateway.enrollments, 2);
  });

  testWidgets('candidate review shows scoped phone and address values', (
    tester,
  ) async {
    final gateway = _Gateway()..failFirstPromotion = false;
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(gateway, authorized: true, size: const Size(768, 900)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handoff-referral-$_convert')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.tap(find.text('Buscar possíveis alunos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+5511999990000'), findsOneWidget);
    expect(find.textContaining('Rua B'), findsOneWidget);
    expect(find.textContaining('Rua A'), findsOneWidget);
  });

  testWidgets('screen reader receives the successful handoff outcome', (
    tester,
  ) async {
    final gateway = _Gateway()..failFirstPromotion = false;
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(gateway, authorized: true, size: const Size(768, 900)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handoff-referral-$_convert')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar aluno a partir desta referência'));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(
            find
                .bySemanticsLabel(
                  'Vínculo confirmado. A matrícula é uma etapa separada.',
                )
                .first,
          )
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('referral and candidate result pages expose pagination', (
    tester,
  ) async {
    final gateway = _Gateway()..pagingEnabled = true;
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(gateway, authorized: true, size: const Size(768, 900)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Carregar mais convertidos'), findsOneWidget);
    await tester.tap(find.text('Carregar mais convertidos'));
    await tester.pumpAndSettle();
    expect(find.text('Bia Lima'), findsOneWidget);
    await tester.tap(find.byKey(const Key('handoff-referral-$_convert')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.tap(find.text('Buscar possíveis alunos'));
    await tester.pumpAndSettle();
    expect(find.text('Ver mais alunos'), findsOneWidget);
    final moreCandidates = find.text('Ver mais alunos');
    await _dragPageUntilHitTestable(tester, moreCandidates);
    await tester.tap(moreCandidates);
    await tester.pumpAndSettle();
    expect(gateway.candidateReads, 2);
    expect(find.text('Ana Maria Souza'), findsOneWidget);
  });

  testWidgets('active class selector supports later pages', (tester) async {
    final gateway = _Gateway()
      ..pagingEnabled = true
      ..failFirstPromotion = false;
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(gateway, authorized: true, size: const Size(768, 900)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handoff-referral-$_convert')));
    await tester.pumpAndSettle();
    final create = find.text('Criar aluno a partir desta referência');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('Ver mais turmas'), findsOneWidget);
    await tester.tap(find.text('Ver mais turmas'));
    await tester.pumpAndSettle();
    expect(gateway.classReads, 2);
    await tester.tap(find.byKey(const Key('handoff-class-select')));
    await tester.pumpAndSettle();
    expect(find.text('Vida Cristã'), findsOneWidget);
  });

  testWidgets('pending promotion locks referral selection', (tester) async {
    final gateway = _Gateway()
      ..pagingEnabled = true
      ..failFirstPromotion = false
      ..promotionCompleter = Completer<Map<String, dynamic>>();
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(gateway, authorized: true, size: const Size(768, 900)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais convertidos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handoff-referral-$_convert')));
    await tester.pumpAndSettle();
    final create = find.text('Criar aluno a partir desta referência');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pump();
    final other = find.byKey(const Key('handoff-referral-$_convert2'));
    await tester.ensureVisible(other);
    expect(tester.widget<ListTile>(other).onTap, isNull);
    await tester.tap(other);
    await tester.pump();
    gateway.promotionCompleter!.complete({
      'convert_id': _convert,
      'student_id': _student,
      'congregation_id': _scope,
      'status': 'linked',
    });
    await tester.pumpAndSettle();
    final firstTile = tester.widget<ListTile>(
      find.byKey(const Key('handoff-referral-$_convert')),
    );
    expect(firstTile.selected, isTrue);
    expect(find.text('Ana Maria'), findsWidgets);
    expect(find.text('Bia Lima'), findsOneWidget);
  });

  testWidgets('candidate search cannot overlap a pending promotion', (
    tester,
  ) async {
    final gateway = _Gateway()
      ..pagingEnabled = true
      ..failFirstPromotion = false
      ..promotionCompleter = Completer<Map<String, dynamic>>();
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(gateway, authorized: true, size: const Size(768, 900)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handoff-referral-$_convert')));
    await tester.pumpAndSettle();
    final create = find.text('Criar aluno a partir desta referência');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pump();

    final searchField = tester.widget<TextField>(find.byType(TextField).first);
    expect(searchField.enabled, isFalse);
    searchField.onSubmitted?.call('Ana');
    await tester.pump();

    expect(gateway.promotions, 1);
    expect(gateway.candidateReads, 0);
    gateway.promotionCompleter!.completeError(const DataFailure('unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(gateway.candidateReads, 0);
  });

  testWidgets(
    'all ministry screens remain vertical at phone, tablet and desktop',
    (tester) async {
      final gateway = _Gateway();
      final ministry = MinistryRepository(gateway);
      final browser = MinistryBrowserRepository(gateway);
      final screens = <Widget Function()>[
        () => MinistryHomePage(
          loadOverview: () => ministry.getOverview(congregationId: _scope),
          scopeName: 'Central',
          onOpenStudents: () {},
          onOpenClasses: () {},
          onOpenAttendance: () {},
        ),
        () => TeamPage(repository: ministry, congregationId: _scope),
        () => StudentsPage(
          repository: browser,
          congregationId: _scope,
          onOpenHandoff: () {},
        ),
        () => ClassesPage(
          repository: browser,
          congregationId: _scope,
          onOpenAttendance: () {},
        ),
        () => AttendancePage(repository: ministry, congregationId: _scope),
        () => ConvertHandoffPage(
          congregationId: _scope,
          canPromote: true,
          handoff: MinistryHandoffRepository(gateway),
          browser: browser,
          ministry: ministry,
        ),
      ];
      for (final size in [
        const Size(360, 800),
        const Size(768, 900),
        const Size(1440, 1000),
      ]) {
        await tester.binding.setSurfaceSize(size);
        for (final screen in screens) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: size),
                child: screen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(_hasHorizontalOverflow(tester), isFalse);
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('attendance pending sessions advances to the next cursor', (
    tester,
  ) async {
    final gateway = _Gateway()..pagingEnabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AttendancePage(
          repository: MinistryRepository(gateway),
          congregationId: _scope,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Carregar mais chamadas'), findsOneWidget);
    await tester.tap(find.text('Carregar mais chamadas'));
    await tester.pumpAndSettle();
    expect(find.text('Fundamentos avançados'), findsOneWidget);
  });

  testWidgets(
    'long congregation scope remains selectable across phone paging',
    (tester) async {
      const centralId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const northId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      const centralName =
          'Assembleia de Deus em Pernambuco - Congregação Central do Recife';
      String? selectedId;
      var pageNumber = 1;
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: StatefulBuilder(
              builder: (context, rebuild) => MinistryHomePage(
                loadOverview: () async => const {
                  'students': 1,
                  'classes': 1,
                  'open_sessions': 0,
                  'through_date': '2026-10-17',
                },
                scopeName: selectedId == null
                    ? 'Selecione uma congregação'
                    : centralName,
                availableCongregationIds: pageNumber == 1
                    ? const [centralId]
                    : selectedId == null
                    ? const [northId]
                    : [selectedId!, northId],
                congregationNames: const {
                  centralId: centralName,
                  northId: 'Congregação Norte',
                },
                selectedCongregationId: selectedId,
                onSelectCongregation: (value) => rebuild(() {
                  selectedId = value;
                }),
                scopeRequired: selectedId == null,
                scopedActionsEnabled: selectedId != null,
                hasNextCongregationPage: pageNumber == 1,
                congregationPageNumber: pageNumber,
                onNextCongregationPage: pageNumber == 1
                    ? () => rebuild(() => pageNumber = 2)
                    : null,
                onOpenStudents: () {},
                onOpenClasses: () {},
                onOpenAttendance: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final studentsAction = find.text('Alunos');
      await tester.scrollUntilVisible(
        studentsAction,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: studentsAction,
                matching: find.byWidgetPredicate(
                  (widget) => widget is ButtonStyleButton,
                ),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text('Turmas'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ButtonStyleButton,
                ),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Página 1'), findsOneWidget);

      final congregationPicker = find.byType(DropdownButtonFormField<String>);
      await tester.scrollUntilVisible(
        congregationPicker,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(congregationPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text(centralName).last);
      await tester.pumpAndSettle();
      expect(selectedId, centralId);
      expect(tester.takeException(), isNull);

      final nextPage = find.text('Próxima');
      await tester.scrollUntilVisible(
        nextPage,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(nextPage);
      await tester.pumpAndSettle();

      expect(find.text('Página 2'), findsOneWidget);
      expect(find.text(centralName), findsAtLeastNWidgets(1));
      await tester.scrollUntilVisible(
        congregationPicker,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final picker = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(picker.value, centralId);
      expect(picker.items!.map((item) => item.value), [centralId, northId]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'attendance controls stay reachable at 200 percent text on phone',
    (tester) async {
      const studentName =
          'Alexandre dos Santos de Albuquerque da Silva e Oliveira';
      final gateway = _Gateway()..pagingEnabled = true;
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: AttendancePage(
              repository: MinistryRepository(gateway),
              congregationId: _scope,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final session = find.text('Fundamentos');
      await _dragPageUntilHitTestable(tester, session);
      await tester.tap(session);
      await tester.pumpAndSettle();

      expect(find.text(studentName), findsOneWidget);
      expect(tester.takeException(), isNull);
      final status = find.byType(DropdownButtonFormField<AttendanceStatus>);
      await _dragPageUntilHitTestable(tester, status);
      await tester.tap(status);
      await tester.pumpAndSettle();
      expect(find.text('Presente'), findsOneWidget);
      await tester.tap(find.text('Presente'));
      await tester.pumpAndSettle();

      final save = find.text('Salvar e finalizar');
      await _dragPageUntilHitTestable(tester, save);
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _dragPageUntilHitTestable(
  WidgetTester tester,
  Finder target,
) async {
  final page = find.byType(ListView).last;
  for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(page, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
  expect(target.hitTestable(), findsOneWidget);
}

bool _hasHorizontalOverflow(WidgetTester tester) {
  final scrollables = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            (widget.axisDirection == AxisDirection.left ||
                widget.axisDirection == AxisDirection.right),
      )
      .evaluate();
  return scrollables.any((element) {
    final state = (element as StatefulElement).state as ScrollableState;
    return state.position.hasContentDimensions &&
        state.position.maxScrollExtent > state.position.minScrollExtent;
  });
}
