import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/ui/students_page.dart';

const _congregationId = 'b0000000-0000-4000-8000-000000000001';

class _BrowserGateway
    implements ReadRpcGateway, StudentRegistrationCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();

  final registrationRequests =
      <({String operationId, Map<String, Object?> payload})>[];
  String? registrationFailure;

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

  @override
  Future<MutationResult<PersonRegistrationResult>> registerStudent(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    registrationRequests.add((
      operationId: operationId,
      payload: Map<String, Object?>.from(payload),
    ));
    if (registrationFailure case final code?) {
      throw DataFailure(code);
    }
    if (registrationRequests.length == 1) {
      // The server may have committed before its response was lost.
      throw const DataFailure('unavailable');
    }
    return MutationResult.applied(
      operationId: operationId,
      value: PersonRegistrationResult(
        personId: payload['person_id']! as String,
        studentId: payload['id']! as String,
        personRevision: 1,
        studentRevision: 1,
      ),
    );
  }
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

  testWidgets('convert form shows only the shared editable person fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConvertForm(onSubmit: (_) async {})),
      ),
    );

    expect(find.byKey(const ValueKey('person-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-birth-date')), findsNothing);
    expect(find.byKey(const ValueKey('person-address-street')), findsOneWidget);
    expect(find.text('Endereço'), findsOneWidget);
    expect(find.byKey(const ValueKey('person-address-district')), findsNothing);
    expect(find.byKey(const ValueKey('person-address-city')), findsNothing);
    expect(
      find.byKey(const ValueKey('person-address-postal-code')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('person-address-state-code')),
      findsNothing,
    );
  });

  testWidgets('convert form scrolls the address field above the keyboard', (
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
    final addressField = find.byKey(const ValueKey('person-address-street'));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.showKeyboard(addressField);
    await tester.pumpAndSettle();

    final devicePixelRatio = tester.view.devicePixelRatio;
    final usableBottom =
        tester.view.physicalSize.height / devicePixelRatio -
        tester.view.viewInsets.bottom / devicePixelRatio;
    expect(
      tester.getBottomRight(addressField).dy,
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

  testWidgets(
    'student registration retries an unknown result with its immutable intent',
    (tester) async {
      final gateway = _BrowserGateway();
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StudentRegistrationPage(
            repository: MinistryRepository(gateway),
            congregationId: _congregationId,
            onCancel: () {},
            onSaved: (_) => saved = true,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('person-name')),
        'Aluna de teste',
      );
      await tester.enterText(
        find.byKey(const ValueKey('student-education')),
        'Ensino médio',
      );
      await tester.ensureVisible(find.text('Cadastrar aluno'));
      await tester.tap(find.text('Cadastrar aluno'));
      await tester.pumpAndSettle();

      expect(gateway.registrationRequests, hasLength(1));
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Cadastrar aluno'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(
                of: find.byKey(const ValueKey('person-name')),
                matching: find.byType(TextFormField),
              ),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(
                of: find.byKey(const ValueKey('student-education')),
                matching: find.byType(TextFormField),
              ),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Cancelar'),
            )
            .onPressed,
        isNull,
      );

      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(gateway.registrationRequests, hasLength(2));
      final first = gateway.registrationRequests[0];
      final retry = gateway.registrationRequests[1];
      expect(retry.operationId, first.operationId);
      expect(retry.payload, equals(first.payload));
      expect(saved, isTrue);
    },
  );

  for (final code in ['invalid', 'academic_invalid', 'academic_conflict']) {
    testWidgets(
      'student registration remains editable after definitive $code rejection',
      (tester) async {
        final gateway = _BrowserGateway()..registrationFailure = code;
        var cancelled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: StudentRegistrationPage(
              repository: MinistryRepository(gateway),
              congregationId: _congregationId,
              onCancel: () => cancelled = true,
              onSaved: (_) {},
            ),
          ),
        );

        await tester.enterText(
          find.byKey(const ValueKey('person-name')),
          'Aluna de teste',
        );
        await tester.ensureVisible(find.text('Cadastrar aluno'));
        await tester.tap(find.text('Cadastrar aluno'));
        await tester.pumpAndSettle();

        expect(gateway.registrationRequests, hasLength(1));
        expect(find.text('Tentar novamente'), findsNothing);
        expect(
          find.text(
            'Não foi possível cadastrar o aluno. Confira os dados e tente novamente.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.descendant(
                  of: find.byKey(const ValueKey('person-name')),
                  matching: find.byType(TextFormField),
                ),
              )
              .enabled,
          isTrue,
        );
        final cancel = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Cancelar'),
        );
        expect(cancel.onPressed, isNotNull);
        final cancelButton = find.widgetWithText(OutlinedButton, 'Cancelar');
        await tester.ensureVisible(cancelButton);
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
        expect(cancelled, isTrue);
      },
    );
  }
}
