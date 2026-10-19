import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/ui/base44_widgets.dart';
import 'package:ieadpe_converts/ui/unified_theme.dart';

const _galleryFontFamily = 'GalleryRoboto';

void main() {
  setUpAll(() async {
    await _loadFlutterFont(_galleryFontFamily, 'roboto-regular.ttf');
    await _loadFlutterFont('MaterialIcons', 'materialicons-regular.otf');
  });

  testWidgets(
    'synthetic gallery switches feedback states and confirms actions',
    (tester) async {
      var saved = false;
      var retried = false;

      await _pumpGallery(
        tester,
        size: const Size(360, 900),
        onSave: () => saved = true,
        onRetry: () => retried = true,
      );
      expect(buildUnifiedTheme().colorScheme.tertiary, UnifiedColors.success);
      expect(
        find.bySemanticsLabel('Carregando alunos de exemplo'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Salvar exemplo'), findsOneWidget);
      expect(find.bySemanticsLabel('Ativo'), findsOneWidget);
      expect(find.text('Nenhum aluno cadastrado.'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('gallery-state-empty')),
      );
      await tester.tap(find.byKey(const ValueKey('gallery-state-empty')));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum aluno cadastrado.'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Carregando alunos de exemplo'),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('gallery-state-error')),
      );
      await tester.tap(find.byKey(const ValueKey('gallery-state-error')));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível carregar os dados.'), findsOneWidget);
      await tester.ensureVisible(find.text('Tentar carregar novamente'));
      await tester.tap(find.text('Tentar carregar novamente'));
      // The loading preview contains a repeating progress indicator.
      await tester.pump();
      expect(retried, isTrue);
      expect(
        find.bySemanticsLabel('Carregando alunos de exemplo'),
        findsOneWidget,
      );
      expect(find.text('Não foi possível carregar os dados.'), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('gallery-search')));
      await tester.enterText(
        find.byKey(const ValueKey('gallery-search')),
        'Ana',
      );
      expect(find.text('Ana'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('gallery-save')));
      await tester.tap(find.byKey(const ValueKey('gallery-save')));
      await tester.pump();
      expect(saved, isTrue);
      expect(find.bySemanticsLabel('Salvo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery remains usable at 360, 768, and 1440 with 200 percent text',
    (tester) async {
      for (final width in [360.0, 768.0, 1440.0]) {
        await _pumpGallery(tester, size: Size(width, 900));

        expect(find.text('Componentes compartilhados'), findsOneWidget);
        expect(find.byKey(const ValueKey('gallery-save')), findsOneWidget);
        expect(find.bySemanticsLabel('Buscar pessoas'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('gallery-save')));
        expect(
          find.byKey(const ValueKey('gallery-save')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('gallery captures readable scrolled responsive states', (
    tester,
  ) async {
    for (final (size, textScale, prefix) in [
      (const Size(360, 900), 1.0, '360'),
      (const Size(768, 900), 1.0, '768'),
      (const Size(1440, 1200), 1.0, '1440'),
      (const Size(360, 900), 2.0, '360_text_200'),
    ]) {
      await _pumpGallery(tester, size: size, textScale: textScale);
      await _captureGallery(tester, '${prefix}_top.png');

      await tester.ensureVisible(find.byKey(const ValueKey('gallery-search')));
      await _captureGallery(tester, '${prefix}_actions.png');

      for (final (kind, suffix) in [
        (Base44FeedbackKind.loading, 'loading'),
        (Base44FeedbackKind.empty, 'empty'),
        (Base44FeedbackKind.error, 'error'),
      ]) {
        final stateKey = ValueKey('gallery-state-${kind.name}');
        await tester.ensureVisible(find.byKey(stateKey));
        await tester.tap(find.byKey(stateKey));
        if (kind == Base44FeedbackKind.loading) {
          // pumpAndSettle cannot complete while the indeterminate spinner runs.
          await tester.pump();
        } else {
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('gallery-feedback')),
        );
        await _captureGallery(tester, '${prefix}_$suffix.png');
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'gallery motion becomes immediate when reduced motion is enabled',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var second = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: _galleryTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  Base44AnimatedSwitcher(
                    child: Text(
                      second ? 'Segundo estado' : 'Primeiro estado',
                      key: ValueKey(second),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => setState(() => second = true),
                    child: const Text('Alternar estado'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
      await tester.tap(find.text('Alternar estado'));
      await tester.pump();
      expect(find.text('Segundo estado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SyntheticGallery extends StatefulWidget {
  const _SyntheticGallery({super.key, this.onSave, this.onRetry});

  final VoidCallback? onSave;
  final VoidCallback? onRetry;

  @override
  State<_SyntheticGallery> createState() => _SyntheticGalleryState();
}

class _SyntheticGalleryState extends State<_SyntheticGallery> {
  Base44FeedbackKind _feedbackKind = Base44FeedbackKind.loading;
  bool _saved = false;

  void _save() {
    setState(() => _saved = true);
    widget.onSave?.call();
  }

  void _retry() {
    setState(() => _feedbackKind = Base44FeedbackKind.loading);
    widget.onRetry?.call();
  }

  Widget _stateControl(Base44FeedbackKind kind, String label) => ChoiceChip(
    key: ValueKey('gallery-state-${kind.name}'),
    label: Text(label),
    labelStyle: Theme.of(context).textTheme.labelLarge,
    selected: _feedbackKind == kind,
    onSelected: (selected) {
      if (selected) setState(() => _feedbackKind = kind);
    },
  );

  Widget _feedback() => switch (_feedbackKind) {
    Base44FeedbackKind.loading => Base44FeedbackState(
      key: const ValueKey('loading-preview'),
      kind: Base44FeedbackKind.loading,
      message: 'Carregando alunos',
      semanticsLabel: 'Carregando alunos de exemplo',
    ),
    Base44FeedbackKind.empty => const Base44FeedbackState(
      key: ValueKey('empty-preview'),
      kind: Base44FeedbackKind.empty,
      message: 'Nenhum aluno cadastrado.',
    ),
    Base44FeedbackKind.error => Base44FeedbackState(
      key: const ValueKey('error-preview'),
      kind: Base44FeedbackKind.error,
      message: 'Não foi possível carregar os dados.',
      actionLabel: 'Tentar carregar novamente',
      onAction: _retry,
    ),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('gallery-capture'),
      child: ColoredBox(
        color: UnifiedColors.page,
        child: SafeArea(
          child: Base44PageContent(
            child: SingleChildScrollView(
              key: const ValueKey('gallery-scroll'),
              padding: const EdgeInsets.symmetric(vertical: UnifiedSpace.x6),
              child: Column(
                key: const ValueKey('gallery-content'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Base44PageHeading(
                    title: 'Componentes compartilhados',
                    subtitle: 'Prévia com dados fictícios',
                    icon: Icons.dashboard_customize_outlined,
                  ),
                  const SizedBox(height: UnifiedSpace.x6),
                  const Base44Hero(
                    child: Text(
                      'Galeria sintética para revisar ações e estados.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: UnifiedSpace.x6),
                  Base44Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Base44SectionHeading(title: 'Ações'),
                        const SizedBox(height: UnifiedSpace.x4),
                        FilledButton(
                          key: const ValueKey('gallery-save'),
                          onPressed: _save,
                          child: const Text('Salvar exemplo'),
                        ),
                        const SizedBox(height: UnifiedSpace.x2),
                        const FilledButton(
                          onPressed: null,
                          child: Text('Ação indisponível'),
                        ),
                        const SizedBox(height: UnifiedSpace.x2),
                        OutlinedButton(
                          onPressed: () {},
                          child: const Text('Ação secundária'),
                        ),
                        const SizedBox(height: UnifiedSpace.x4),
                        const TextField(
                          key: ValueKey('gallery-search'),
                          decoration: InputDecoration(
                            label: Text('Buscar pessoas', maxLines: 2),
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: UnifiedSpace.x4),
                        Wrap(
                          spacing: UnifiedSpace.x2,
                          runSpacing: UnifiedSpace.x2,
                          children: [
                            Base44StatusBadge(
                              label: _saved ? 'Salvo' : 'Ativo',
                              tone: Base44StatusTone.success,
                            ),
                            const Base44StatusBadge(
                              label: 'Aguardando',
                              tone: Base44StatusTone.warning,
                            ),
                            const Base44StatusBadge(
                              label: 'Com atenção',
                              tone: Base44StatusTone.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: UnifiedSpace.x6),
                        const Base44SectionHeading(
                          title: 'Estado de demonstração',
                        ),
                        const SizedBox(height: UnifiedSpace.x2),
                        Wrap(
                          key: const ValueKey('gallery-state-controls'),
                          spacing: UnifiedSpace.x2,
                          runSpacing: UnifiedSpace.x2,
                          children: [
                            _stateControl(
                              Base44FeedbackKind.loading,
                              'Carregando',
                            ),
                            _stateControl(Base44FeedbackKind.empty, 'Vazio'),
                            _stateControl(Base44FeedbackKind.error, 'Erro'),
                          ],
                        ),
                        const SizedBox(height: UnifiedSpace.x3),
                        KeyedSubtree(
                          key: const ValueKey('gallery-feedback'),
                          child: Base44AnimatedSwitcher(child: _feedback()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpGallery(
  WidgetTester tester, {
  required Size size,
  double textScale = 2,
  VoidCallback? onSave,
  VoidCallback? onRetry,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: _galleryTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: _SyntheticGallery(
        key: ValueKey((size, textScale)),
        onSave: onSave,
        onRetry: onRetry,
      ),
    ),
  );
}

ThemeData _galleryTheme() {
  final theme = buildUnifiedTheme();
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: _galleryFontFamily),
  );
}

Future<void> _captureGallery(WidgetTester tester, String fileName) async {
  // This also captures the loading state, whose indeterminate spinner never
  // settles by design. Gallery state transitions have zero duration.
  await tester.pump();
  await expectLater(
    find.byKey(const ValueKey('gallery-capture')),
    matchesGoldenFile('goldens/ministry_component_gallery_$fileName'),
  );
}

Future<void> _loadFlutterFont(String family, String fileName) async {
  final fontFile = _findFlutterFont(fileName);
  final fontBytes = await fontFile.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)));
  await loader.load();
}

File _findFlutterFont(String fileName) {
  var directory = Directory(Platform.resolvedExecutable).parent;
  while (true) {
    final candidate = File(
      <String>[
        directory.path,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        fileName,
      ].join(Platform.pathSeparator),
    );
    if (candidate.existsSync()) return candidate;

    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError(
    'Could not find $fileName in the Flutter SDK material_fonts artifact.',
  );
}
