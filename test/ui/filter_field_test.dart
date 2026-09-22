import 'package:discipulado_ieadpe/ui/app_theme.dart';
import 'package:discipulado_ieadpe/ui/filter_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

void main() {
  test('filter widths are positive multiples of the 4/8 scale', () {
    expect(AppSizes.filterControlWidth, greaterThan(0));
    expect(AppSizes.filterControlWidth % 4, 0);
    expect(AppSizes.searchControlWidth, greaterThan(0));
    expect(AppSizes.searchControlWidth % 4, 0);
  });

  testWidgets('the label always floats so it never overlaps the value', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppFilterField<String>(
          key: AppFilterFieldTestKeys.congregation,
          label: 'Congregação',
          value: null,
          nullLabel: 'Todas',
          options: <AppFilterOption<String>>[
            AppFilterOption<String>(value: 'c1', label: 'Alvorada'),
          ],
          onChanged: (_) {},
        ),
      ),
    );

    final Finder field = find.byType(DropdownButtonFormField<String?>);
    expect(field, findsOneWidget);
    final DropdownButtonFormField<String?> dropdown =
        tester.widget<DropdownButtonFormField<String?>>(field);
    expect(
      dropdown.decoration.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
    expect(find.text('Congregação'), findsOneWidget);
  });

  testWidgets('a null option is offered first and selection reports value', (
    tester,
  ) async {
    String? selected;
    await pumpApp(
      tester,
      Scaffold(
        body: AppFilterField<String>(
          key: AppFilterFieldTestKeys.congregation,
          label: 'Congregação',
          value: null,
          nullLabel: 'Todas',
          options: <AppFilterOption<String>>[
            AppFilterOption<String>(value: 'c1', label: 'Alvorada'),
            AppFilterOption<String>(value: 'c2', label: 'Xingu'),
          ],
          onChanged: (String? value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    expect(find.text('Todas'), findsWidgets);
    expect(find.text('Xingu'), findsOneWidget);

    await tester.tap(find.text('Xingu'));
    await tester.pumpAndSettle();
    expect(selected, 'c2');
    expect(find.text('Xingu'), findsOneWidget);
  });

  testWidgets('a long congregation name truncates with an ellipsis', (
    tester,
  ) async {
    const String longName = 'Assembléia de Deus Ministério do Belém';
    await pumpApp(
      tester,
      Scaffold(
        body: AppFilterField<String>(
          key: AppFilterFieldTestKeys.congregation,
          label: 'Congregação',
          value: null,
          nullLabel: 'Todas',
          options: <AppFilterOption<String>>[
            AppFilterOption<String>(
              value: 'c1',
              label: longName,
              key: AppFilterFieldTestKeys.longOption,
            ),
          ],
          onChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();

    final Text longText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(AppFilterFieldTestKeys.longOption),
        matching: find.byType(Text),
      ),
    );
    expect(longText.overflow, TextOverflow.ellipsis);
    expect(longText.maxLines, 1);
  });

  testWidgets('a disabled filter opens nothing and reports no change', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppFilterField<String>(
          key: AppFilterFieldTestKeys.congregation,
          label: 'Congregação',
          value: 'c1',
          nullLabel: 'Todas',
          options: <AppFilterOption<String>>[
            AppFilterOption<String>(value: 'c1', label: 'Alvorada'),
          ],
          enabled: false,
          onChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();

    final Finder field = find.byType(DropdownButtonFormField<String?>);
    final DropdownButtonFormField<String?> dropdown =
        tester.widget<DropdownButtonFormField<String?>>(field);
    expect(dropdown.onChanged, isNull);
  });
}

abstract final class AppFilterFieldTestKeys {
  static const Key congregation = Key('filter-field-test-congregation');
  static const Key longOption = Key('filter-field-test-long-option');
}