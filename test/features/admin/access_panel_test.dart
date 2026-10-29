import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/admin/access_panel.dart';

import '../converts/save_test.dart' show TestGateway;

class _AccessGateway extends TestGateway {
  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => [
    {
      'id': '1',
      'user_email': 'member@example.test',
      'user_id': 'user',
      'role': 'Membro da direção da campanha',
      'congregation_id': 'a',
    },
    {
      'id': '2',
      'user_email': 'member@example.test',
      'user_id': 'user',
      'role': 'Membro da direção da campanha',
      'congregation_id': 'b',
    },
  ];
}

void main() {
  testWidgets('access list reveals all congregations including legacy grants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccessPanel(
              gateway: _AccessGateway(),
              congregations: const [
                Congregation(id: 'a', name: 'João Rufino'),
                Congregation(id: 'b', name: 'Zé Pojuca III'),
              ],
              canOpenTeam: true,
              onOpenTeam: () {},
              onScopeRefresh: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Direção · João Rufino'), findsOneWidget);
    expect(find.text('Direção · Zé Pojuca III'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing@example.test');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum acesso encontrado.'), findsOneWidget);
  });
}
