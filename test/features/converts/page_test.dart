import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/convert_repository.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/converts/edit_page.dart';
import 'package:ieadpe_converts/features/converts/register_page.dart';
import 'package:ieadpe_converts/domain/worship_types.dart';

import 'form_test.dart' show record;
import 'save_test.dart' show TestGateway, NoPhotos;
import '../../support/date_picker.dart';

void main() {
  testWidgets('edit page publishes minimal ID only after applied command', (
    t,
  ) async {
    final gateway = TestGateway()..fail = false;
    String? saved;
    await t.pumpWidget(
      MaterialApp(
        home: EditPage(
          scope: AccessScope(congregationIds: [record().congregationId!]),
          initial: record(
            personId: 'person',
            personRevision: 7,
            personIdentity: const CanonicalPersonIdentity(name: 'Pessoa'),
          ),
          converts: ConvertRepository(gateway),
          photos: NoPhotos(),
          onSaved: (id) => saved = id,
        ),
      ),
    );
    await t.ensureVisible(find.text('Atualizar'));
    await t.tap(find.text('Atualizar'));
    await t.pumpAndSettle();
    expect(saved, 'id');
    expect(find.text('Convertido atualizado com sucesso!'), findsOneWidget);
    expect(gateway.calls.single['command'], 'edit_convert');
    expect(gateway.calls.single['payload'], containsPair('id', 'id'));
    expect(
      gateway.calls.single['payload'],
      containsPair('expected_person_revision', 7),
    );
  });

  testWidgets('own-scope registration stays on the official save controller', (
    t,
  ) async {
    final gateway = TestGateway()..fail = false;
    final congregationId = record().congregationId!;
    String? saved;
    var challengeCreations = 0;
    await t.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          converts: ConvertRepository(gateway),
          photos: NoPhotos(),
          scope: AccessScope(congregationIds: [congregationId]),
          congregations: [
            Congregation(id: congregationId, name: 'Congregação Central'),
          ],
          revalidateScope: (_) async => true,
          turnstileChallengeFactory: () {
            challengeCreations++;
            throw StateError('own-scope saves do not require Turnstile');
          },
          onSaved: (id) => saved = id,
        ),
      ),
    );

    await t.tap(find.text('Congregação *'));
    await t.pumpAndSettle();
    await t.tap(find.text('Congregação Central').last);
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('person-name')),
        matching: find.byType(EditableText),
      ),
      'Pessoa de Teste',
    );
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('landmark')),
        matching: find.byType(EditableText),
      ),
      'Praça central',
    );
    final gender = find.byKey(const ValueKey('convert-gender'));
    await t.ensureVisible(gender);
    await t.tap(gender);
    await t.pumpAndSettle();
    await t.tap(find.text('Feminino').last);
    await t.pumpAndSettle();
    await pickDate(t, const ValueKey('conversion_date'), DateTime.now());
    final worship = find.byKey(const ValueKey('convert-worship'));
    await t.ensureVisible(worship);
    await t.tap(worship);
    await t.pumpAndSettle();
    await t.tap(find.text(worshipTypes.first).last);
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('Cadastrar'));
    await t.tap(find.text('Cadastrar'));
    await t.pumpAndSettle();

    expect(saved, 'record');
    expect(gateway.calls.single['command'], 'create_convert');
    expect(challengeCreations, 0);
    expect(
      find.text('Novo convertido cadastrado com sucesso!'),
      findsOneWidget,
    );
  });
}
