import 'package:discipulado_ieadpe/features/team/phone_actions.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';

void main() {
  test('phoneDigits keeps only the normalized phone digits', () {
    expect(phoneDigits('+55 (11) 98765-4321'), '5511987654321');
    expect(phoneDigits(null), '');
  });

  test('whatsAppUrl is a digits-only wa.me link or null', () {
    final String? url = whatsAppUrl('+55 (11) 98765-4321');
    expect(url, 'https://wa.me/5511987654321');
    expect(url, isNot(contains('+')));
    expect(url, isNot(contains('(')));
    expect(RegExp(r'^https://wa\.me/\d+$').hasMatch(url!), isTrue);
    expect(whatsAppUrl(null), isNull);
    expect(whatsAppUrl(''), isNull);
  });

  testWidgets('WhatsApp activates explicitly with the digits-only target', (
    WidgetTester tester,
  ) async {
    Uri? launched;
    await pumpApp(
      tester,
      Scaffold(
        body: PhoneActions(
          phoneE164: '+55 (11) 98765-4321',
          onLaunch: (Uri uri) async {
            launched = uri;
            return true;
          },
          onCopy: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(PhoneActions.whatsAppKey));
    await tester.pump();

    expect(launched, isNotNull);
    expect(launched!.host, 'wa.me');
    expect(launched!.pathSegments.single, '5511987654321');
  });

  testWidgets('copy fallback receives the phone digits', (
    WidgetTester tester,
  ) async {
    String? copied;
    await pumpApp(
      tester,
      Scaffold(
        body: PhoneActions(
          phoneE164: '+55 (11) 98765-4321',
          onLaunch: (_) async => true,
          onCopy: (String digits) async {
            copied = digits;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(PhoneActions.copyKey));
    await tester.pump();

    expect(copied, '5511987654321');
  });

  testWidgets('a missing phone disables WhatsApp with explanatory text', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const Scaffold(body: PhoneActions(phoneE164: null)));

    expect(find.byKey(PhoneActions.missingKey), findsOneWidget);
    expect(find.text('Telefone não informado'), findsOneWidget);
    final AppButton whatsapp = tester.widget<AppButton>(
      find.byKey(PhoneActions.whatsAppKey),
    );
    expect(whatsapp.onPressed, isNull);
  });
}
