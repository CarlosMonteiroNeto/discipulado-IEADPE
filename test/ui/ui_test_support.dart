import 'package:discipulado_ieadpe/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [home] inside a [MaterialApp] at an explicit logical viewport size.
///
/// The viewport is set on the test view (not only on MediaQuery) so layout
/// constraints match the width under test. Text scaling uses the dispatcher
/// test value so `MediaQuery.textScalerOf` and the render tree agree.
Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  double width = 1280,
  double height = 900,
  double textScale = 1.0,
  ThemeData? theme,
  Widget Function(Widget child)? wrap,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  final Widget content = wrap == null ? home : wrap(home);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? AppTheme.light,
      home: content,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Sets [text] directly on the controller backing the editable with [fieldKey].
///
/// Read-only fields (e.g. date fields that open a picker) ignore `enterText`,
/// so tests that want to seed a value must write to the [TextEditingController]
/// the field holds. Requires the field to be discoverable below [fieldKey].
Future<void> setFormText(
  WidgetTester tester,
  Key fieldKey,
  String text,
) async {
  final Finder editable = find.descendant(
    of: find.byKey(fieldKey),
    matching: find.byType(EditableText),
  );
  expect(editable, findsOneWidget);
  tester.widget<EditableText>(editable).controller.text = text;
  await tester.pump();
}
