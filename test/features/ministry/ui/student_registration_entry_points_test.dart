import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/ui/students_page.dart';

const _congregationId = 'b0000000-0000-4000-8000-000000000001';

class _BrowserGateway implements ReadRpcGateway {
  @override
  final boundary = ProtectedDataBoundary();

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async => {'items': <Object>[], 'next_cursor': null};

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
  ) async => MutationResult.applied(operationId: operationId, value: 'record');
}

void main() {
  testWidgets(
    'students page exposes the authorized shared registration entry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentsPage(
            repository: MinistryBrowserRepository(_BrowserGateway()),
            congregationId: _congregationId,
            onOpenHandoff: () {},
            onRegister: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registrar aluno'), findsOneWidget);
    },
  );

  testWidgets('convert form uses the shared canonical person field keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConvertForm(onSubmit: (_) async {})),
      ),
    );

    expect(find.byKey(const ValueKey('person-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-birth-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-address-street')), findsOneWidget);
  });

  testWidgets('convert form scrolls canonical fields above the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConvertForm(onSubmit: (_) async {})),
      ),
    );
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final lastField = find.byKey(const ValueKey('person-address-state-code'));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.showKeyboard(lastField);
    await tester.pumpAndSettle();

    final devicePixelRatio = tester.view.devicePixelRatio;
    final usableBottom =
        tester.view.physicalSize.height / devicePixelRatio -
        tester.view.viewInsets.bottom / devicePixelRatio;
    expect(
      tester.getBottomRight(lastField).dy,
      lessThanOrEqualTo(usableBottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('student registration uses person and academic fields only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentRegistrationPage(
          repository: MinistryRepository(_BrowserGateway()),
          congregationId: _congregationId,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('person-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-birth-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-education')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-marital-status')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('conversion_date')), findsNothing);
    expect(find.text('Data de conversão'), findsNothing);
  });
}
