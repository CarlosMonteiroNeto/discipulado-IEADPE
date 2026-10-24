import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/ui/br_input.dart';

void main() {
  group('Brazilian phone input', () {
    test('formats the national 11-digit mobile shape', () {
      expect(formatBrPhone('11999990001'), '(11) 9 9999-0001');
      expect(formatBrPhone('(11) 99999-0001'), '(11) 9 9999-0001');
      expect(formatBrPhone('+55 11 99999-0001'), '(11) 9 9999-0001');
      expect(brPhoneDisplay('+5511999990001'), '(11) 9 9999-0001');
    });

    test('shows a stored value outside the mask verbatim for correction', () {
      expect(brPhoneDisplay('1199990000'), '1199990000');
      expect(brPhoneDisplay('telefone antigo'), 'telefone antigo');
    });

    test('keeps partial input readable while the user types', () {
      expect(formatBrPhone('11'), '(11');
      expect(formatBrPhone('119'), '(11) 9');
      expect(formatBrPhone('1199999'), '(11) 9 9999');
    });

    test('normalizes valid numbers to E.164 and refuses anything else', () {
      expect(brPhoneE164('(11) 9 9999-0001'), '+5511999990001');
      expect(brPhoneE164('11999990001'), '+5511999990001');
      expect(brPhoneE164('1199990000'), null);
      expect(brPhoneE164(''), null);
    });

    test('rejects empty required, short, and invalid DDD values', () {
      expect(brPhoneValidationError('', required: true), 'Informe o telefone.');
      expect(brPhoneValidationError(''), null);
      expect(
        brPhoneValidationError('(11) 9 9999-000'),
        'O telefone deve ter 11 dígitos.',
      );
      expect(
        brPhoneValidationError('(00) 9 9999-0001'),
        'Informe um DDD válido.',
      );
      expect(brPhoneValidationError('(11) 9 9999-0001'), null);
    });
  });

  group('Brazilian date input', () {
    test('formats ISO and already-display dates as dd/MM/yyyy', () {
      expect(formatBrDate(DateTime(2026, 1, 2)), '02/01/2026');
      expect(brDateDisplay('2026-01-02'), '02/01/2026');
      expect(brDateDisplay('02/01/2026'), '02/01/2026');
      expect(brDateDisplay(null), '');
    });

    test('parses display and ISO dates, rejecting impossible days', () {
      expect(parseBrDate('02/01/2026'), DateTime(2026, 1, 2));
      expect(parseDateInput('2026-01-02'), DateTime(2026, 1, 2));
      expect(parseDateInput('31/02/2026'), null);
    });

    test('validates required and malformed values', () {
      expect(brDateValidationError('', required: true), 'Informe a data.');
      expect(brDateValidationError(''), null);
      expect(brDateValidationError('31/02/2026'), 'Informe uma data válida.');
      expect(brDateValidationError('02/01/2026'), null);
    });
  });
}
