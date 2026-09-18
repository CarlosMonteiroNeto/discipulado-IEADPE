import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:discipulado_ieadpe/ui/record_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

class _Student {
  const _Student(this.name, this.className);

  final String name;
  final String className;
}

const String _longAccentedName =
    'Maria José da Conceição Araújo e Silva dos Santos Oliveira';

final List<_Student> _students = <_Student>[
  const _Student(_longAccentedName, 'Discipulado 2026 — Congregação Central'),
  const _Student('João', 'Turma A'),
];

List<AppRecordColumn<_Student>> _columns() => <AppRecordColumn<_Student>>[
  AppRecordColumn<_Student>(
    label: 'Nome',
    cell: (context, item) => Text(item.name),
  ),
  AppRecordColumn<_Student>(
    label: 'Turma',
    cell: (context, item) => Text(item.className),
  ),
];

Widget _list({ValueChanged<_Student>? onOpen}) => AppRecordList<_Student>(
  items: _students,
  columns: _columns(),
  onOpen: onOpen,
  toolbar: AppButton(label: 'Novo aluno', onPressed: () {}),
  emptyMessage: 'Nenhum aluno encontrado',
);

void main() {
  testWidgets('wide viewports render a titled table region', (tester) async {
    await pumpApp(tester, Scaffold(body: _list()), width: 768);

    expect(find.byKey(AppRecordList.tableKey), findsOneWidget);
    expect(find.byKey(AppRecordList.tableScrollKey), findsOneWidget);
    expect(find.byKey(AppRecordList.cardsKey), findsNothing);
    expect(find.text('Nome'), findsOneWidget);
  });

  testWidgets(
    'narrow viewports render record cards without a page-wide table',
    (tester) async {
      await pumpApp(tester, Scaffold(body: _list()), width: 360);

      expect(find.byKey(AppRecordList.cardsKey), findsOneWidget);
      expect(find.byKey(AppRecordList.tableKey), findsNothing);
      expect(find.byKey(AppRecordList.tableScrollKey), findsNothing);
      expect(find.text(_longAccentedName), findsOneWidget);
    },
  );

  testWidgets(
    'long accented names wrap at 360 with 200% text without overflow',
    (tester) async {
      await pumpApp(
        tester,
        Scaffold(body: _list()),
        width: 360,
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_longAccentedName), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
    },
  );

  testWidgets(
    'the toolbar primary action stays visible at 360 with 200% text',
    (tester) async {
      await pumpApp(
        tester,
        Scaffold(body: _list()),
        width: 360,
        textScale: 2.0,
      );

      final button = find.byType(AppButton);
      final rect = tester.getRect(button);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
    },
  );

  testWidgets('empty datasets show the empty message', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppRecordList<_Student>(
          items: const <_Student>[],
          columns: _columns(),
          emptyMessage: 'Nenhum aluno encontrado',
        ),
      ),
      width: 768,
    );

    expect(find.text('Nenhum aluno encontrado'), findsOneWidget);
    expect(find.byKey(AppRecordList.tableKey), findsNothing);
    expect(find.byKey(AppRecordList.cardsKey), findsNothing);
  });

  testWidgets('records open from both table and card presentations', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpApp(
      tester,
      Scaffold(body: _list(onOpen: (item) => opened.add(item.name))),
      width: 360,
    );
    await tester.tap(find.text(_longAccentedName));
    await tester.pumpAndSettle();
    expect(opened, <String>[_longAccentedName]);

    await pumpApp(
      tester,
      Scaffold(body: _list(onOpen: (item) => opened.add(item.name))),
      width: 768,
    );
    await tester.tap(find.text(_longAccentedName));
    await tester.pumpAndSettle();
    expect(opened.last, _longAccentedName);
  });
}
