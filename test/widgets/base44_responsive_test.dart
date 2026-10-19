import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/converts/convert_card.dart';
import 'package:ieadpe_converts/ui/base44_widgets.dart';
import 'package:ieadpe_converts/ui/unified_theme.dart';

import '../features/converts/list_test.dart' show PendingPhotos;
import '../features/converts/save_test.dart' show TestGateway;

void main() {
  testWidgets(
    'long convert cards stay readable and keep contact and confirmations reachable at 320px and 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final today = DateOnly(2026, 10, 18);
      const congregation = Congregation(
        id: 'congregation',
        name: 'Congregação Central com um nome muito extenso para testar a quebra de linha',
      );
      ConvertRecord record(
        String id, {
        required DateOnly converted,
        bool discipleship = false,
        bool visited = false,
        String? phone,
        String? photo,
      }) => ConvertRecord(
        id: id,
        internalId: 'legacy-$id',
        name:
            'Pessoa com nome extenso que precisa continuar totalmente legível $id',
        landmark: 'Ponto de referência com uma descrição longa que deve quebrar em mais de uma linha',
        gender: Gender.female,
        conversionDate: converted,
        worshipType:
            'Culto com descrição extensa para testar o espaço disponível',
        congregationId: congregation.id,
        photoAssetId: photo,
        address: 'Endereço muito longo na Avenida da Igreja, número 12345, bairro central, Recife, Pernambuco',
        phone: phone,
        age: 0,
        wasVisitedOnce: visited,
        visitCount: 2,
        isInDiscipleship: discipleship,
      );

      final gateway = TestGateway();
      final photos = PendingPhotos();
      var edited = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final item in [
                      record(
                        'urgent',
                        converted: today.addDays(-2),
                        photo: 'broken-photo',
                      ),
                      record('attention', converted: today),
                      record(
                        'current',
                        converted: today,
                        discipleship: true,
                        visited: true,
                        phone: '(81) 99999-1234',
                      ),
                    ])
                      ConvertCard(
                        record: item,
                        today: today,
                        congregation: congregation,
                        gateway: gateway,
                        photos: photos,
                        onAction: (_) async {},
                        onEdit: () => edited = true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      photos.metadata.completeError(Exception('fixture photo failure'));
      await tester.pumpAndSettle();

      Future<void> scrollTo(Finder target) => tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Visita Urgente'), findsOneWidget);
      await scrollTo(find.text('Atenção'));
      expect(find.text('Atenção'), findsOneWidget);
      await scrollTo(find.text('Em dia'));
      expect(find.text('Em dia'), findsOneWidget);
      await scrollTo(
        find.text(
          'Pessoa com nome extenso que precisa continuar totalmente legível urgent',
        ),
      );
      expect(
        find.text(
          'Pessoa com nome extenso que precisa continuar totalmente legível urgent',
        ),
        findsOneWidget,
      );
      expect(find.text('Não foi possível carregar a foto.'), findsOneWidget);
      final whatsapp = tester.widget<FilledButton>(
        find.widgetWithIcon(FilledButton, Icons.chat_bubble_outline).first,
      );
      expect(whatsapp.onPressed, isNull);

      await tester.ensureVisible(find.text('Editar').last);
      expect(find.text('Editar').last.hitTestable(), findsOneWidget);
      await tester.tap(find.text('Editar').last);
      expect(edited, isTrue);

      await tester.ensureVisible(find.text('Excluir').first);
      await tester.tap(find.text('Excluir').first);
      await tester.pumpAndSettle();
      expect(find.text('Confirmar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared page content uses its inset and width tokens while preserving large-text actions',
    (tester) async {
      var activated = 0;
      for (final (width, expectedContentWidth) in [
        (360.0, 328.0),
        (768.0, 720.0),
        (1440.0, 848.0),
      ]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = buildUnifiedTheme();

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Base44PageContent(
                    child: SizedBox(
                      key: const ValueKey('responsive-content'),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Base44PageHeading(
                            title: 'Uma página com título longo e acessível',
                            subtitle: 'Prévia em fonte ampliada',
                            icon: Icons.people_outline,
                            trailing: FilledButton(
                              key: const ValueKey('responsive-page-action'),
                              onPressed: () => activated += 1,
                              child: const Text('Abrir detalhes completos'),
                            ),
                          ),
                          const SizedBox(height: UnifiedSpace.sectionGap),
                          const Base44Panel(
                            child: Base44StatusBadge(
                              label: 'Aguardando retorno do responsável',
                              tone: Base44StatusTone.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          tester
              .getSize(find.byKey(const ValueKey('responsive-page-action')))
              .width,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('responsive-content')))
              .width,
          expectedContentWidth,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('responsive-page-action')),
        );
        expect(
          find.byKey(const ValueKey('responsive-page-action')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('responsive-page-action')));
        expect(tester.takeException(), isNull);
      }
      expect(activated, 3);
    },
  );

  testWidgets(
    'section heading stacks a long action after its title at phone text scales',
    (tester) async {
      const title =
          'Acompanhamento detalhado de participantes da turma de discipulado';
      var activated = false;

      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUnifiedTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Base44PageContent(
                  child: Base44SectionHeading(
                    title: title,
                    trailing: FilledButton(
                      key: const ValueKey('section-heading-action'),
                      onPressed: () => activated = true,
                      child: const Text('Abrir participantes pendentes'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final titleRect = tester.getRect(find.text(title));
        final actionRect = tester.getRect(
          find.byKey(const ValueKey('section-heading-action')),
        );
        expect(actionRect.top, greaterThanOrEqualTo(titleRect.bottom + 8));
        await tester.ensureVisible(
          find.byKey(const ValueKey('section-heading-action')),
        );
        expect(
          find.byKey(const ValueKey('section-heading-action')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('section-heading-action')));
        expect(tester.takeException(), isNull);
      }
      expect(activated, isTrue);
    },
  );
}
