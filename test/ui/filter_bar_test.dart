import 'package:discipulado_ieadpe/ui/app_theme.dart';
import 'package:discipulado_ieadpe/ui/filter_bar.dart';
import 'package:discipulado_ieadpe/ui/filter_field.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

void main() {
  const Key f1 = Key('bar-field-1');
  const Key f2 = Key('bar-field-2');
  const Key a1 = Key('bar-action-1');

  AppFilterBar bar() => AppFilterBar(
    fields: <Widget>[
      AppFilterField<String>(
        key: f1,
        label: 'Buscar por nome',
        value: null,
        nullLabel: 'Todos',
        options: const <AppFilterOption<String>>[
          AppFilterOption<String>(value: 'a', label: 'Ana'),
        ],
        onChanged: (_) {},
      ),
      AppFilterField<String>(
        key: f2,
        label: 'Congregação',
        value: null,
        nullLabel: 'Todas',
        options: const <AppFilterOption<String>>[
          AppFilterOption<String>(value: 'c1', label: 'Alvorada'),
        ],
        onChanged: (_) {},
      ),
    ],
    actions: <Widget>[
      AppButton(
        key: a1,
        label: 'Atualizar',
        variant: AppButtonVariant.secondary,
        onPressed: () {},
      ),
    ],
  );

  testWidgets('a wide bar gives every field an equal width and aligned edges', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: bar(),
        ),
      ),
      width: 1280,
    );

    final Rect r1 = tester.getRect(find.byKey(f1));
    final Rect r2 = tester.getRect(find.byKey(f2));
    expect(r1.width, r2.width);

    // Actions sit on the trailing side of the aligned fields.
    final Rect actions = tester.getRect(find.byKey(a1));
    expect(actions.left, greaterThanOrEqualTo(r2.right));
    expect(actions.right, 1280 - AppSpacing.x4);
  });

  testWidgets('a compact bar stacks fields full width and right-aligns actions', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: bar(),
        ),
      ),
      width: 360,
      height: 700,
    );

    final double contentWidth = 360 - 2 * AppSpacing.x4;
    expect(tester.getSize(find.byKey(f1)).width, contentWidth);
    expect(tester.getSize(find.byKey(f2)).width, contentWidth);

    // Fields stack vertically.
    expect(
      tester.getRect(find.byKey(f1)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(f2)).top),
    );

    // Actions are right-aligned on their own line.
    final double contentRight = AppSpacing.x4 + contentWidth;
    final Rect actions = tester.getRect(find.byKey(a1));
    expect(actions.right, contentRight);
  });
}