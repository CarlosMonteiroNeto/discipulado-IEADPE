import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/ui/session_form.dart';
import 'package:ieadpe_converts/features/ministry/ui/session_list.dart';
import 'package:ieadpe_converts/ui/unified_theme.dart';

const _congregation = '33333333-3333-4333-8333-333333333333';
const _class = '22222222-2222-4222-8222-222222222222';
const _session = '55555555-5555-4555-8555-555555555555';
const _font = 'SessionVisualRoboto';

class _VisualGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  @override
  void ensureCurrent(String value) {
    if (value != context) throw const DataFailure('stale');
  }

  bool empty = false;
  bool fail = false;
  Completer<Map<String, dynamic>>? pendingList;
  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    if (fail) throw const DataFailure('unavailable');
    if (rpc == 'ministry_list_class_sessions' && pendingList != null) {
      return pendingList!.future;
    }
    if (rpc == 'ministry_list_class_sessions')
      return {
        'items': empty
            ? <Object>[]
            : [
                {
                  'id': _session,
                  'class_id': _class,
                  'congregation_id': _congregation,
                  'date': '2026-12-20',
                  'topic': 'Uma lição sobre perseverança, serviço e cuidado pastoral em comunidade',
                  'status': 'canceled',
                  'revision': 2,
                },
                {
                  'id': '77777777-7777-4777-8777-777777777777',
                  'class_id': _class,
                  'congregation_id': _congregation,
                  'date': '2026-12-27',
                  'topic': 'Tema longo para verificar a adaptação do conteúdo em telas estreitas',
                  'status': 'finalized',
                  'revision': 3,
                },
                {
                  'id': '88888888-8888-4888-8888-888888888888',
                  'class_id': _class,
                  'congregation_id': _congregation,
                  'date': '2027-01-03',
                  'topic': 'Registro histórico adicional para conferir a rolagem da lista',
                  'status': 'canceled',
                  'revision': 4,
                },
              ],
        'next_cursor': null,
      };
    if (rpc == 'ministry_get_session_attendance') {
      final id = parameters['session_id'] as String;
      final first = id == _session;
      return {
        'session': {
          'id': id,
          'class_id': _class,
          'congregation_id': _congregation,
          'date': first ? '2026-12-20' : '2026-12-27',
          'topic': first
              ? 'Uma lição sobre perseverança, serviço e cuidado pastoral em comunidade'
              : 'Tema longo para verificar a adaptação do conteúdo em telas estreitas',
          'status': 'open',
          'roster_frozen': false,
          'lesson_index': null,
          'lesson_part': null,
          'lesson_finished': false,
          'revision': 2,
          'created_at': '2026-10-01T00:00:00Z',
          'updated_at': '2026-10-01T00:00:00Z',
          'updated_by': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        },
        'roster': <Object>[],
      };
    }
    throw UnimplementedError(rpc);
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String name,
    String operationId,
    Map<String, Object?> payload,
  ) async => {'id': payload['id'], 'revision': 1, 'status': 'open'};
  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

void main() {
  final productionTheme = buildUnifiedTheme();
  final theme = productionTheme.copyWith(
    textTheme: productionTheme.textTheme.apply(fontFamily: _font),
    primaryTextTheme: productionTheme.primaryTextTheme.apply(fontFamily: _font),
  );

  for (final spec in <({String name, Size size, double scale})>[
    (name: '360x900', size: const Size(360, 900), scale: 1),
    (name: '1440x900', size: const Size(1440, 900), scale: 1),
    (name: '360x900-text-200', size: const Size(360, 900), scale: 2),
  ]) {
    testWidgets('session surfaces visual ${spec.name}', (tester) async {
      await tester.runAsync(() async {
        await _loadFont(_font, 'roboto-regular.ttf');
        await _loadFont('MaterialIcons', 'materialicons-regular.otf');
      });
      // TEMP_PROGRESS
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = spec.size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final gateway = _VisualGateway();
      final repository = MinistryRepository(gateway);
      final klass = MinistryClassSummary(
        id: _class,
        name: 'Fundamentos bíblicos e formação cristã para a comunidade local',
        status: ClassStatus.active,
        startDate: '2026-10-01',
        endDate: null,
        revision: 1,
        teacherContactId: null,
      );

      late Future<void> Function(String captureName) capture;
      capture = (String captureName) async {
        final output = File(
          'docs/verification/l1/$captureName-${spec.name}.png',
        );
        await tester.runAsync(() async {
          await output.parent.create(recursive: true);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('visual-capture')),
          );
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await output.writeAsBytes(
            bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        });
      };

      Future<void> mount(Widget child, String captureName) async {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(spec.scale)),
              child: RepaintBoundary(
                key: const ValueKey('visual-capture'),
                child: child!,
              ),
            ),
            home: ColoredBox(color: Colors.white, child: child),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(captureName);
      }

      Future<void> mountLoading() async {
        gateway.pendingList = Completer<Map<String, dynamic>>();
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(spec.scale)),
              child: RepaintBoundary(
                key: const ValueKey('visual-capture'),
                child: child!,
              ),
            ),
            home: ColoredBox(
              color: Colors.white,
              child: SessionListPage(
                repository: repository,
                congregationId: _congregation,
                classSummary: klass,
                onOpenSession: (_) async {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 250));
        await capture('session-loading');
        gateway.pendingList!.complete({
          'items': <Object>[],
          'next_cursor': null,
        });
        gateway.pendingList = null;
        await tester.pumpAndSettle();
      }

      await mount(
        SessionForm(
          repository: repository,
          congregationId: _congregation,
          classSummary: klass,
        ),
        'session-form',
      );
      final save = find.widgetWithText(FilledButton, 'Salvar');
      expect(find.text('Formato: DD/MM/AAAA'), findsOneWidget);
      expect(
        tester.getRect(find.text('Formato: DD/MM/AAAA')).right,
        lessThanOrEqualTo(spec.size.width),
      );
      await tester.ensureVisible(save);
      expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(save).width, greaterThanOrEqualTo(48));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      gateway.empty = false;
      await mount(
        SessionListPage(
          repository: repository,
          congregationId: _congregation,
          classSummary: klass,
          onOpenSession: (_) async {},
        ),
        'session-list',
      );
      expect(find.textContaining('Cancelada ·'), findsWidgets);
      expect(find.textContaining('Finalizada ·'), findsOneWidget);
      final create = find.widgetWithText(FilledButton, 'Nova aula');
      final createRect = tester.getRect(create);
      expect(createRect.left, greaterThanOrEqualTo(0));
      expect(createRect.right, lessThanOrEqualTo(spec.size.width));
      expect(createRect.top, greaterThanOrEqualTo(0));
      expect(createRect.bottom, lessThanOrEqualTo(spec.size.height));
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      expect(tester.getSize(create).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(create).width, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);

      final cancel = find.byKey(
        const Key('cancel-session-77777777-7777-4777-8777-777777777777'),
      );
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      final cancelRect = tester.getRect(cancel);
      expect(cancelRect.left, greaterThanOrEqualTo(0));
      expect(cancelRect.right, lessThanOrEqualTo(spec.size.width));
      expect(cancelRect.top, greaterThanOrEqualTo(0));
      expect(cancelRect.bottom, lessThanOrEqualTo(spec.size.height));
      await capture('session-list-cancel-action');
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      final approve = find.widgetWithText(FilledButton, 'Cancelar aula');
      await tester.ensureVisible(approve);
      expect(tester.getSize(approve).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(approve).width, greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining(
            'Tema longo para verificar a adaptação do conteúdo em telas estreitas',
          ),
        ),
        findsOneWidget,
      );
      final output = File(
        'docs/verification/l1/session-cancel-dialog-${spec.name}.png',
      );
      await tester.runAsync(() async {
        await output.parent.create(recursive: true);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('visual-capture')),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await output.writeAsBytes(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      });
      expect(dialog, findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      gateway.empty = true;
      await mount(
        SessionListPage(
          repository: repository,
          congregationId: _congregation,
          classSummary: klass,
          onOpenSession: (_) async {},
        ),
        'session-empty',
      );
      expect(find.text('Nenhuma aula registrada nesta turma.'), findsOneWidget);
      await mountLoading();
      gateway.fail = true;
      await mount(
        SessionListPage(
          repository: repository,
          congregationId: _congregation,
          classSummary: klass,
          onOpenSession: (_) async {},
        ),
        'session-error',
      );
      expect(
        find.textContaining('Não foi possível carregar as aulas'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  }
}

Future<void> _loadFont(String family, String fileName) async {
  var directory = File(Platform.resolvedExecutable).parent;
  File? font;
  while (true) {
    final candidate = File(
      '${directory.path}${Platform.pathSeparator}bin${Platform.pathSeparator}cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}material_fonts${Platform.pathSeparator}$fileName',
    );
    if (candidate.existsSync()) {
      font = candidate;
      break;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  if (font == null) throw StateError('Could not find $fileName.');
  final loader = FontLoader(family)
    ..addFont(
      Future<ByteData>.value(ByteData.sublistView(await font.readAsBytes())),
    );
  await loader.load();
}
