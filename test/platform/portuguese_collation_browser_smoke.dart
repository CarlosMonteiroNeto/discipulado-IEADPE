import 'dart:convert';
import 'dart:js_interop';

import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/converts/congregation_order.dart';
import 'package:ieadpe_converts/platform/portuguese_sort.dart';

@JS('document.body.textContent')
external set resultText(JSString value);

Future<void> main() async {
  try {
    const input = [
      'São',
      'Sao',
      'são',
      'sao',
      'Sede',
      'Sede Nova',
      'área',
      'Área',
      'Area',
      'area',
      'Ação',
      'Acao',
      'ação',
      'Zebra',
      'Água',
    ];
    const expected = [
      'Acao',
      'ação',
      'Ação',
      'Água',
      'area',
      'Area',
      'área',
      'Área',
      'sao',
      'Sao',
      'são',
      'São',
      'Sede',
      'Sede Nova',
      'Zebra',
    ];
    final actual = await sortPortugueseNames(input);
    if (jsonEncode(actual) != jsonEncode(expected)) {
      throw StateError('Locale order: $actual');
    }
    final ordered = await orderCongregations([
      for (final entry in input.indexed)
        Congregation(id: '${entry.$1}', name: entry.$2),
    ]);
    const expectedWithSede = [
      'Sede',
      'Sede Nova',
      'Acao',
      'ação',
      'Ação',
      'Água',
      'area',
      'Area',
      'área',
      'Área',
      'sao',
      'Sao',
      'são',
      'São',
      'Zebra',
    ];
    if (jsonEncode(ordered.map((c) => c.name).toList()) !=
        jsonEncode(expectedWithSede)) {
      throw StateError('Sede order');
    }
    if (jsonEncode(await sortPortugueseNames(['Sa\u0303o', 'São'])) !=
        jsonEncode(['Sa\u0303o', 'São'])) {
      throw StateError('Canonical equivalence');
    }
    if ('Sa\u0303o'.runes.length != 4 || 'São'.runes.length != 3) {
      throw StateError('Canonical fixture encoding');
    }
    resultText = 'PASS: production browser pt-BR collation, sede priority and canonical equivalence'
        .toJS;
  } catch (error) {
    resultText = 'FAIL: $error'.toJS;
  }
}
