import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/ui/async_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

void main() {
  test('AsyncViewState exposes a distinct phase per S09 situation', () {
    expect(const AsyncViewState<int>.loading().phase, AsyncPhase.loading);
    expect(const AsyncViewState<int>.emptyData().phase, AsyncPhase.emptyData);
    expect(
      const AsyncViewState<int>.emptySearch(query: 'maria').phase,
      AsyncPhase.emptySearch,
    );
    expect(AsyncViewState<int>.error(_failure).phase, AsyncPhase.error);
    expect(const AsyncViewState<int>.forbidden().phase, AsyncPhase.forbidden);
    expect(const AsyncViewState<int>.notFound().phase, AsyncPhase.notFound);
    expect(const AsyncViewState<int>.data(7).data, 7);
  });

  test('forbidden and not-found failures map to their own phases', () {
    expect(
      AsyncViewState<int>.fromFailure(
        const AppFailure(code: AppFailureCode.forbidden, message: 'sem acesso'),
      ).phase,
      AsyncPhase.forbidden,
    );
    expect(
      AsyncViewState<int>.fromFailure(
        const AppFailure(code: AppFailureCode.notFound, message: 'sumiu'),
      ).phase,
      AsyncPhase.notFound,
    );
    expect(
      AsyncViewState<int>.fromFailure(
        const AppFailure(code: AppFailureCode.unavailable, message: 'rede'),
      ).phase,
      AsyncPhase.error,
    );
  });

  testWidgets('loading renders a progress indicator without an empty message', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: AsyncContent<int>(state: AsyncViewState<int>.loading()),
      ),
      settle: false,
    );

    expect(find.byKey(AsyncContent.loadingKey), findsOneWidget);
    expect(find.byKey(AsyncContent.emptyDataKey), findsNothing);
    expect(find.byKey(AsyncContent.errorKey), findsNothing);
  });

  testWidgets('empty dataset and empty search are distinct states', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: AsyncContent<int>(state: AsyncViewState<int>.emptyData()),
      ),
    );
    expect(find.byKey(AsyncContent.emptyDataKey), findsOneWidget);
    expect(find.byKey(AsyncContent.emptySearchKey), findsNothing);
    expect(find.byKey(AsyncContent.errorKey), findsNothing);

    await pumpApp(
      tester,
      const Scaffold(
        body: AsyncContent<int>(
          state: AsyncViewState<int>.emptySearch(query: 'maria'),
        ),
      ),
    );
    expect(find.byKey(AsyncContent.emptySearchKey), findsOneWidget);
    expect(find.byKey(AsyncContent.emptyDataKey), findsNothing);
  });

  testWidgets('a load failure is never rendered as an empty database', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AsyncContent<int>(
          state: AsyncViewState<int>.error(_failure),
          onRetry: () async {},
        ),
      ),
    );

    expect(find.byKey(AsyncContent.errorKey), findsOneWidget);
    expect(find.byKey(AsyncContent.emptyDataKey), findsNothing);
    expect(find.text(_failure.message), findsOneWidget);
    expect(find.byKey(AsyncContent.retryKey), findsOneWidget);
  });

  testWidgets('retry invokes the provided callback', (tester) async {
    var retries = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: AsyncContent<int>(
          state: AsyncViewState<int>.error(_failure),
          onRetry: () async => retries++,
        ),
      ),
    );

    await tester.tap(find.byKey(AsyncContent.retryKey));
    await tester.pumpAndSettle();
    expect(retries, 1);
  });

  testWidgets('forbidden and not-found render their own safe messages', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: AsyncContent<int>(state: AsyncViewState<int>.forbidden()),
      ),
    );
    expect(find.byKey(AsyncContent.forbiddenKey), findsOneWidget);
    expect(find.text('Acesso não autorizado'), findsOneWidget);

    await pumpApp(
      tester,
      const Scaffold(
        body: AsyncContent<int>(state: AsyncViewState<int>.notFound()),
      ),
    );
    expect(find.byKey(AsyncContent.notFoundKey), findsOneWidget);
    expect(find.text('Registro não encontrado'), findsOneWidget);
  });

  testWidgets('data state delegates rendering to the builder', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AsyncContent<int>(
          state: const AsyncViewState<int>.data(42),
          dataBuilder: (context, value) => Text('valor $value'),
        ),
      ),
    );

    expect(find.text('valor 42'), findsOneWidget);
  });
}

const AppFailure _failure = AppFailure(
  code: AppFailureCode.unavailable,
  message: 'Não foi possível carregar os dados.',
);
