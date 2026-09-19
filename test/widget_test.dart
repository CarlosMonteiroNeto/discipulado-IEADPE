/// Task 13 acceptance: the S10 route table is complete and creation routes are
/// declared before their parameter routes.
library;

import 'package:discipulado_ieadpe/app/navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every S10 route is declared', () {
    expect(AppRoutes.all.toSet(), <String>{
      '/entrar',
      '/recuperar-senha',
      '/visao-geral',
      '/equipe',
      '/equipe/:contactId',
      '/alunos',
      '/alunos/novo',
      '/alunos/:studentId',
      '/alunos/:studentId/editar',
      '/turmas',
      '/turmas/nova',
      '/turmas/:classId',
      '/turmas/:classId/chamadas/:sessionId',
      '/congregacoes',
    });
  });
}
