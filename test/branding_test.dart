import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
void main() {
 test('web and Android use Portuguese IEADPE church identity', () {
   expect(File('web/index.html').readAsStringSync(), contains('<html lang="pt-BR">'));
   final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
   expect(manifest['name'], 'IEADPE — Novos Convertidos');
   expect(manifest['lang'], 'pt-BR');
   expect((manifest['icons'] as List).first['src'], 'icons/ieadpe.svg');
   final android = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
   expect(android, contains('android:label="IEADPE"'));
   expect(android, contains('android:icon="@drawable/ic_ieadpe"'));
 });
}
