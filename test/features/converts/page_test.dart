import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/convert_repository.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/converts/edit_page.dart';

import 'form_test.dart' show record;
import 'save_test.dart' show TestGateway, NoPhotos;

void main() {
  testWidgets('edit page publishes minimal ID only after applied command', (
    t,
  ) async {
    final gateway = TestGateway()..fail = false;
    String? saved;
    await t.pumpWidget(
      MaterialApp(
        home: EditPage(
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
}
