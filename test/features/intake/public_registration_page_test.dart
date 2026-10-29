import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/app.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';
import 'package:ieadpe_converts/features/intake/intake_models.dart';
import 'package:ieadpe_converts/features/intake/public_intake_page.dart';
import 'package:ieadpe_converts/features/intake/public_intake_repository.dart';
import 'package:ieadpe_converts/features/intake/turnstile_challenge.dart';
import 'package:ieadpe_converts/routing/browser_route_history.dart';
import 'package:ieadpe_converts/domain/worship_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/date_picker.dart';

const _congregationId = '11111111-1111-4111-8111-111111111111';

class _FakePublicIntakeRepository extends PublicIntakeRepository {
  _FakePublicIntakeRepository()
    : super(
        supabaseUrl: Uri.parse('https://project.supabase.co'),
        publishableKey: 'sb_publishable_public-test',
        client: MockClient((_) async => http.Response('{}', 200)),
      );

  int catalogReads = 0;
  List<PublicCongregation> catalog = const [
    PublicCongregation(id: _congregationId, name: 'Congregação Central'),
  ];
  final submissions = <({String id, String token, PublicIntakeDraft draft})>[];
  Future<void> Function(String id, PublicIntakeDraft draft, String token)?
  submitHandler;

  @override
  Future<List<PublicCongregation>> listAllCongregations() async {
    catalogReads++;
    return catalog;
  }

  @override
  Future<void> submit({
    required String submissionId,
    required PublicIntakeDraft draft,
    required String turnstileToken,
  }) async {
    submissions.add((id: submissionId, token: turnstileToken, draft: draft));
    await submitHandler?.call(submissionId, draft, turnstileToken);
  }
}

class _FakeBootstrapHistory implements BrowserRouteHistory {
  _FakeBootstrapHistory(String initialPath) : _paths = [initialPath];

  final List<String> _paths;
  int _index = 0;
  void Function(String path)? _onPop;

  @override
  String? get currentPath => _paths[_index];

  @override
  void listen(void Function(String path) onPop) => _onPop = onPop;

  @override
  void push(String path) {
    _paths.removeRange(_index + 1, _paths.length);
    _paths.add(path);
    _index = _paths.length - 1;
  }

  @override
  void replace(String path) => _paths[_index] = path;

  void back() {
    if (_index == 0) return;
    _index--;
    _onPop?.call(_paths[_index]);
  }

  @override
  void dispose() => _onPop = null;
}

class _FakeTurnstileChallenge implements TurnstileChallenge {
  final tokens = <String>['token-1', 'token-2', 'token-3'];
  int resets = 0;
  int disposals = 0;

  @override
  Widget get view => const Text('Verificação de segurança');

  @override
  bool get isSupported => true;

  @override
  Future<String> acquireToken() async => tokens.removeAt(0);

  @override
  void reset() => resets++;

  @override
  void dispose() => disposals++;
}

class _AuthProbe extends AuthRepository {
  _AuthProbe(this.protectedRequests)
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'sb_publishable_t4-test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            protectedRequests.add(request);
            return http.Response('{}', 500);
          }),
        ),
        AuthRedirectPolicy(Uri.parse('http://127.0.0.1:5173/auth/callback')),
      );

  final List<http.Request> protectedRequests;
  int sessionWatches = 0;
  int scopeReads = 0;
  final intendedRoutes = <String?>[];
  final events = StreamController<Session?>.broadcast(sync: true);
  Session? session;
  AccessScope access = AccessScope();

  @override
  Session? get currentSession => session;

  @override
  Stream<Session?> watchSession() {
    sessionWatches++;
    return events.stream;
  }

  @override
  Future<void> signInWithGoogle({String? intendedRoute}) async {
    intendedRoutes.add(intendedRoute);
  }

  @override
  Future<AccessScope> loadScope() async {
    scopeReads++;
    return access;
  }

  @override
  Future<void> signOut() async {
    session = null;
    events.add(null);
  }
}

Future<void> _fillPublicForm(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Congregação *'));
  await tester.tap(find.text('Congregação *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Congregação Central').last);
  await tester.pumpAndSettle();

  final name = find.descendant(
    of: find.byKey(const ValueKey('person-name')),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(name);
  await tester.enterText(name, 'Pessoa de Teste');
  final landmark = find.descendant(
    of: find.byKey(const ValueKey('landmark')),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(landmark);
  await tester.enterText(landmark, 'Praça central');

  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final gender = find.byKey(const ValueKey('convert-gender'));
  await tester.ensureVisible(gender);
  await tester.tap(gender);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Feminino').last);
  await tester.pumpAndSettle();

  final today = DateTime.now();
  await pickDate(tester, const ValueKey('conversion_date'), today);

  final worship = find.byKey(const ValueKey('convert-worship'));
  await tester.ensureVisible(worship);
  await tester.tap(worship);
  await tester.pumpAndSettle();
  await tester.tap(find.text(worshipTypes.first).last);
  await tester.pumpAndSettle();
}

Future<void> _pumpAppFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    'public form loads a public names-only catalog once without photos',
    (tester) async {
      final repository = _FakePublicIntakeRepository();
      final challenge = _FakeTurnstileChallenge();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicRegistrationPage(
            repository: repository,
            challenge: challenge,
            sortNames: (names) async => names,
          ),
        ),
      );
      await _pumpAppFrames(tester);

      expect(repository.catalogReads, 1);
      await tester.tap(find.text('Congregação *'));
      await tester.pumpAndSettle();
      expect(find.text('Congregação Central'), findsOneWidget);
      await tester.tap(find.text('Congregação Central'));
      await tester.pumpAndSettle();
      expect(find.text('Escolher foto'), findsNothing);
      expect(find.text('Remover foto'), findsNothing);
      expect(find.text('Verificação de segurança'), findsOneWidget);
      expect(repository.submissions, isEmpty);

      final nameField = find.byKey(const ValueKey('person-name')).first;
      final landmarkField = find.byKey(const ValueKey('landmark')).first;
      await tester.ensureVisible(nameField);
      await tester.tap(nameField);
      await tester.pump();
      await tester.ensureVisible(landmarkField);
      await tester.tap(landmarkField);
      await tester.pump();
      expect(find.text('Nome é obrigatório'), findsOneWidget);

      final submit = find.widgetWithText(FilledButton, 'Cadastrar');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final nameEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('person-name')),
          matching: find.byType(EditableText),
        ),
      );
      expect(
        nameEditable.focusNode.hasFocus,
        isTrue,
        reason: 'submit must focus the first invalid field in form order',
      );
    },
  );

  testWidgets(
    'unknown public submit freezes its key and draft for fresh-token retry',
    (tester) async {
      final repository = _FakePublicIntakeRepository();
      final challenge = _FakeTurnstileChallenge();
      var calls = 0;
      repository.submitHandler = (_, _, _) async {
        calls++;
        if (calls == 1) {
          throw const PublicIntakeFailure(
            PublicIntakeFailureCode.unavailable,
            outcomeUnknown: true,
          );
        }
      };
      await tester.pumpWidget(
        MaterialApp(
          home: PublicRegistrationPage(
            repository: repository,
            challenge: challenge,
            sortNames: (names) async => names,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _fillPublicForm(tester);
      final submit = find.widgetWithText(FilledButton, 'Cadastrar');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(repository.submissions, hasLength(1));
      expect(find.text('Tentar envio novamente'), findsOneWidget);
      final name = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('person-name')),
          matching: find.byType(EditableText),
        ),
      );
      expect(name.controller.text, 'Pessoa de Teste');
      expect(name.readOnly, isTrue);

      await tester.ensureVisible(find.text('Tentar envio novamente'));
      await tester.tap(find.text('Tentar envio novamente'));
      await tester.pumpAndSettle();
      expect(repository.submissions, hasLength(2));
      expect(repository.submissions[1].id, repository.submissions[0].id);
      expect(
        repository.submissions[1].draft.toJson(),
        repository.submissions[0].draft.toJson(),
      );
      expect(repository.submissions.map((item) => item.token), [
        'token-1',
        'token-2',
      ]);
      expect(
        find.text('Cadastro enviado para análise da congregação.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('person-name')), findsNothing);
    },
  );

  testWidgets('definitive validation rejection preserves an editable draft', (
    tester,
  ) async {
    final repository = _FakePublicIntakeRepository()
      ..submitHandler = (_, _, _) async {
        throw const PublicIntakeFailure(PublicIntakeFailureCode.validation);
      };
    await tester.pumpWidget(
      MaterialApp(
        home: PublicRegistrationPage(
          repository: repository,
          challenge: _FakeTurnstileChallenge(),
          sortNames: (names) async => names,
        ),
      ),
    );
    await _pumpAppFrames(tester);
    await _fillPublicForm(tester);
    final submit = find.widgetWithText(FilledButton, 'Cadastrar');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.submissions, hasLength(1));
    expect(
      find.text('Confira os dados do cadastro e tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Tentar envio novamente'), findsNothing);
    final name = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('person-name')),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.controller.text, 'Pessoa de Teste');
    expect(name.readOnly, isFalse);
  });

  testWidgets('rapid repeat activation creates one public request', (
    tester,
  ) async {
    final repository = _FakePublicIntakeRepository();
    final pending = Completer<void>();
    repository.submitHandler = (_, _, _) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicRegistrationPage(
          repository: repository,
          challenge: _FakeTurnstileChallenge(),
          sortNames: (names) async => names,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _fillPublicForm(tester);
    final submit = find.widgetWithText(FilledButton, 'Cadastrar');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(repository.submissions, hasLength(1));

    final busyButton = find.widgetWithText(FilledButton, 'Salvando…');
    expect(tester.widget<FilledButton>(busyButton).onPressed, isNull);
    await tester.tap(busyButton, warnIfMissed: false);
    await tester.pump();
    expect(repository.submissions, hasLength(1));

    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'root and register bootstrap without protected reads, then login on demand',
    (tester) async {
      final repository = _FakePublicIntakeRepository();
      final protectedRequests = <http.Request>[];
      final auth = _AuthProbe(protectedRequests);
      final challenges = <_FakeTurnstileChallenge>[];
      _FakeTurnstileChallenge newChallenge() {
        final challenge = _FakeTurnstileChallenge();
        challenges.add(challenge);
        return challenge;
      }

      for (final path in const ['/', '/register']) {
        await tester.pumpWidget(
          App(
            key: ValueKey(path),
            initialPath: path,
            auth: auth,
            publicIntakeRepository: repository,
            turnstileChallengeFactory: newChallenge,
          ),
        );
        await _pumpAppFrames(tester);
        expect(find.text('Cadastro público'), findsOneWidget);
        expect(repository.catalogReads, greaterThan(0));
        expect(auth.sessionWatches, 0);
        expect(auth.scopeReads, 0);
        expect(protectedRequests, isEmpty);
      }
      expect(repository.catalogReads, 2);

      await tester.pumpWidget(
        App(
          key: const ValueKey('public-route-login-on-demand'),
          initialPath: '/',
          auth: auth,
          publicIntakeRepository: repository,
          turnstileChallengeFactory: newChallenge,
        ),
      );
      await _pumpAppFrames(tester);
      expect(auth.sessionWatches, 0);
      await tester.tap(find.byKey(const ValueKey('app-shell-sign-in')));
      await _pumpAppFrames(tester);
      expect(find.text('Entrar com Google'), findsOneWidget);
      expect(auth.sessionWatches, 1);
      expect(auth.scopeReads, 0);
      expect(protectedRequests, isEmpty);
      await tester.tap(find.text('Entrar com Google'));
      await _pumpAppFrames(tester);
      expect(auth.intendedRoutes, ['/home']);
      expect(repository.catalogReads, 3);
      await tester.pumpWidget(const SizedBox());
      expect(challenges.every((challenge) => challenge.disposals == 1), isTrue);
      var disposed = false;
      final disposal = auth.client.dispose().then((_) => disposed = true);
      for (var attempt = 0; attempt < 30 && !disposed; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        disposed,
        isTrue,
        reason: 'fake AuthRepository client should dispose',
      );
      await disposal;
    },
  );

  testWidgets('browser deep link survives anonymous sign in', (tester) async {
    final auth = _AuthProbe(<http.Request>[]);
    final history = _FakeBootstrapHistory('/converts');
    await tester.pumpWidget(
      App(
        auth: auth,
        publicIntakeRepository: _FakePublicIntakeRepository(),
        turnstileChallengeFactory: _FakeTurnstileChallenge.new,
        browserRouteHistoryFactory: () => history,
      ),
    );
    await _pumpAppFrames(tester);
    await tester.tap(find.byKey(const ValueKey('app-shell-sign-in')));
    await _pumpAppFrames(tester);
    await tester.tap(find.text('Entrar com Google'));
    await _pumpAppFrames(tester);
    expect(auth.intendedRoutes, ['/converts']);
    await tester.pumpWidget(const SizedBox());
    await auth.events.close();
    var disposed = false;
    final disposal = auth.client.dispose().then((_) => disposed = true);
    for (var attempt = 0; attempt < 30 && !disposed; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(disposed, isTrue);
    await disposal;
  });

  testWidgets('browser Back from login restores public registration', (
    tester,
  ) async {
    final protectedRequests = <http.Request>[];
    final auth = _AuthProbe(protectedRequests);
    final repository = _FakePublicIntakeRepository();
    final history = _FakeBootstrapHistory('/');
    final challenges = <_FakeTurnstileChallenge>[];
    _FakeTurnstileChallenge newChallenge() {
      final challenge = _FakeTurnstileChallenge();
      challenges.add(challenge);
      return challenge;
    }

    addTearDown(() async {
      await auth.events.close();
      var disposed = false;
      final disposal = auth.client.dispose().then((_) => disposed = true);
      for (var attempt = 0; attempt < 30 && !disposed; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        disposed,
        isTrue,
        reason: 'fake AuthRepository client should dispose',
      );
      await disposal;
    });

    await tester.pumpWidget(
      App(
        initialPath: '/',
        auth: auth,
        publicIntakeRepository: repository,
        turnstileChallengeFactory: newChallenge,
        browserRouteHistoryFactory: () => history,
      ),
    );
    await _pumpAppFrames(tester);
    expect(find.text('Cadastro público'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-shell-sign-in')));
    await _pumpAppFrames(tester);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('Voltar ao cadastro'), findsOneWidget);
    expect(history.currentPath, '/home');

    history.back();
    await _pumpAppFrames(tester);
    expect(history.currentPath, '/');
    expect(find.text('Cadastro público'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsNothing);
    expect(protectedRequests, isEmpty);

    await tester.pumpWidget(const SizedBox());
    expect(challenges.every((challenge) => challenge.disposals == 1), isTrue);
  });

  testWidgets(
    'authenticated no-grant register uses public names and pending submission',
    (tester) async {
      final protectedRequests = <http.Request>[];
      final auth = _AuthProbe(protectedRequests)
        ..session = Session(
          accessToken: 'synthetic',
          tokenType: 'bearer',
          user: User(
            id: 'user-without-grants',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-15T00:00:00Z',
          ),
        );
      final repository = _FakePublicIntakeRepository();
      repository.catalog = const [
        PublicCongregation(
          id: '33333333-3333-4333-8333-333333333333',
          name: 'Zeta',
        ),
        PublicCongregation(id: _congregationId, name: 'Congregação Central'),
        PublicCongregation(
          id: '44444444-4444-4444-8444-444444444444',
          name: 'Sede Alfa',
        ),
      ];
      const localeChannel = MethodChannel('br.org.ieadpe/locale');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(localeChannel, (call) async {
        final names = List<String>.from(call.arguments as List)..sort();
        return names;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(localeChannel, null),
      );
      final challenges = <_FakeTurnstileChallenge>[];
      _FakeTurnstileChallenge newChallenge() {
        final challenge = _FakeTurnstileChallenge();
        challenges.add(challenge);
        return challenge;
      }

      addTearDown(() async => auth.events.close());

      await tester.pumpWidget(
        App(
          initialPath: '/home',
          auth: auth,
          publicIntakeRepository: repository,
          turnstileChallengeFactory: newChallenge,
        ),
      );
      await _pumpAppFrames(tester);
      expect(find.text('Cadastrar Novo Convertido'), findsOneWidget);
      expect(repository.catalogReads, 1);
      expect(auth.scopeReads, 1);
      expect(protectedRequests, isEmpty);
      expect(find.text('Escolher foto'), findsNothing);
      expect(find.text('Verificação de segurança'), findsOneWidget);
      final congregationField = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('convert-congregation')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(
        congregationField.items!
            .map((item) => (item.child as Text).data)
            .toList(),
        ['Congregação Central', 'Sede Alfa', 'Zeta'],
        reason: 'public catalog rows use locale ordering',
      );

      await _fillPublicForm(tester);
      final submit = find.widgetWithText(FilledButton, 'Cadastrar');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repository.submissions, hasLength(1));
      expect(repository.submissions.single.token, 'token-1');
      expect(protectedRequests, isEmpty);
      expect(
        auth.scopeReads,
        2,
        reason: 'submission scope must be revalidated',
      );

      await tester.tap(find.byKey(const ValueKey('app-shell-sign-out')));
      await _pumpAppFrames(tester);
      expect(find.text('Cadastro público'), findsOneWidget);
      expect(repository.catalogReads, 2);
      expect(auth.scopeReads, 2);
      final blankName = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('person-name')),
          matching: find.byType(EditableText),
        ),
      );
      expect(blankName.controller.text, isEmpty);
      expect(protectedRequests, isEmpty);

      await tester.pumpWidget(const SizedBox());
      expect(challenges.every((challenge) => challenge.disposals == 1), isTrue);
      var disposed = false;
      final disposal = auth.client.dispose().then((_) => disposed = true);
      for (var attempt = 0; attempt < 30 && !disposed; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        disposed,
        isTrue,
        reason: 'fake AuthRepository client should dispose',
      );
      await disposal;
    },
  );
}
