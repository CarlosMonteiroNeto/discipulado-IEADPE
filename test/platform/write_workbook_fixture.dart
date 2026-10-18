import 'dart:io';

import 'package:ieadpe_converts/platform/table_workbook.dart';

void main(List<String> args) {
  File(args.single).writeAsBytesSync(
    tableWorkbook('Eventos', [
      [
        'Convertido',
        'Congregação',
        'Evento',
        'Data do Evento',
        'Registrado por',
      ],
      for (var i = 1; i <= 1205; i++)
        ['João $i', 'São José', '=1+2', '01/10/2026', 'ação@example.test'],
    ]),
  );
}
