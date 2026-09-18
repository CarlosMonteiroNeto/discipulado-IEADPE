import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('name normalization', () {
    test('lowercases and removes diacritics', () {
      expect(normalizeName('João'), 'joao');
      expect(normalizeName('José'), 'jose');
      expect(normalizeName('AÇÃO'), 'acao');
      expect(normalizeName('  Ángela  '), 'angela');
    });

    test('accented and unaccented display names share one normalized key', () {
      expect(normalizeName('Ángela'), normalizeName('Angela'));
      expect(normalizeName('ANTÔNIO'), normalizeName('antonio'));
    });

    test('keeps non-letter name characters intact while folding case', () {
      expect(normalizeName("D'Ávila"), "d'avila");
    });
  });

  group('display name validation', () {
    test('accepts a trimmed name at the two-character minimum', () {
      expect(validateDisplayName('  Al  '), isNull);
    });

    test('rejects names shorter than two trimmed characters', () {
      expect(validateDisplayName(' A '), isNotNull);
      expect(validateDisplayName(''), isNotNull);
      expect(validateDisplayName('   '), isNotNull);
    });

    test('accepts up to one hundred twenty trimmed characters', () {
      expect(validateDisplayName('a' * 120), isNull);
    });

    test('rejects names longer than one hundred twenty characters', () {
      expect(validateDisplayName('a' * 121), isNotNull);
    });

    test('preserves a Unicode display name instead of rewriting it', () {
      expect(validateDisplayName('João'), isNull);
      expect(normalizeName('João'), isNot('João'));
    });
  });

  group('Brazilian phone normalization', () {
    test('normalizes a formatted mobile number to E.164', () {
      expect(normalizeBrazilianPhone('(81) 99999-9999'), '+5581999999999');
    });

    test('normalizes an unformatted national mobile number', () {
      expect(normalizeBrazilianPhone('81999999999'), '+5581999999999');
    });

    test('normalizes the +55 form', () {
      expect(normalizeBrazilianPhone('+55 81 99999-9999'), '+5581999999999');
    });

    test('normalizes a ten-digit landline number', () {
      expect(normalizeBrazilianPhone('(81) 3232-1010'), '+558132321010');
    });

    test('accepts empty optional phone input', () {
      expect(normalizeBrazilianPhone(null), isNull);
      expect(normalizeBrazilianPhone(''), isNull);
      expect(normalizeBrazilianPhone('   '), isNull);
      expect(validatePhone(null), isNull);
      expect(validatePhone('   '), isNull);
    });

    test('rejects a number that is neither ten nor eleven digits', () {
      expect(validatePhone('11999999'), isNotNull);
      expect(validatePhone('119999999999'), isNotNull);
    });

    test(
      'rejects an eleven-digit number whose subscriber does not start 9',
      () {
        expect(validatePhone('81 89999-9999'), isNotNull);
      },
    );

    test('rejects a DDD beginning with zero', () {
      expect(validatePhone('0899999999'), isNotNull);
    });

    test('rejects a non-Brazilian international number', () {
      expect(validatePhone('+1 202 555 0134'), isNotNull);
    });

    test('rejects letters embedded in the number', () {
      expect(validatePhone('81 99999-999a'), isNotNull);
    });
  });

  group('birth date validation', () {
    test('rejects a date that is still in the future in America/Recife', () {
      // 02:00 UTC on 2026-03-10 is 23:00 on 2026-03-09 in Recife (UTC-3).
      final now = DateTime.utc(2026, 3, 10, 2, 0);
      expect(
        validateBirthDate(CalendarDate(2026, 3, 10), nowUtc: now),
        isNotNull,
      );
    });

    test('accepts today once the Recife day has arrived', () {
      final now = DateTime.utc(2026, 3, 10, 3, 0);
      expect(validateBirthDate(CalendarDate(2026, 3, 10), nowUtc: now), isNull);
    });

    test('rejects a birth date before 1900', () {
      expect(
        validateBirthDate(
          CalendarDate(1899, 12, 31),
          nowUtc: DateTime.utc(2026, 1, 1),
        ),
        isNotNull,
      );
    });

    test('accepts an age below ten without an artificial minimum', () {
      // 12:00 UTC is 09:00 on the same day in Recife (UTC-3).
      final now = DateTime.utc(2026, 1, 1, 12);
      expect(validateBirthDate(CalendarDate(2018, 5, 4), nowUtc: now), isNull);
      expect(validateBirthDate(CalendarDate(2026, 1, 1), nowUtc: now), isNull);
    });

    test('accepts an empty optional birth date', () {
      expect(validateBirthDate(null, nowUtc: DateTime.utc(2026, 1, 1)), isNull);
    });
  });

  group('religious answers validation', () {
    test('accepts not-informed answers', () {
      expect(
        validateBaptismAnswers(waterBaptized: null, wantsBaptism: null),
        isNull,
      );
    });

    test('accepts baptized with wantsBaptism explicitly false', () {
      expect(
        validateBaptismAnswers(waterBaptized: true, wantsBaptism: false),
        isNull,
      );
    });

    test('accepts baptized with wantsBaptism not informed', () {
      expect(
        validateBaptismAnswers(waterBaptized: true, wantsBaptism: null),
        isNull,
      );
    });

    test('accepts unbaptized wanting baptism', () {
      expect(
        validateBaptismAnswers(waterBaptized: false, wantsBaptism: true),
        isNull,
      );
    });

    test('rejects baptized and wants-baptism together', () {
      expect(
        validateBaptismAnswers(waterBaptized: true, wantsBaptism: true),
        isNotNull,
      );
    });
  });

  group('optional text and address validation', () {
    test('accepts empty optional address fields', () {
      expect(validateAddressFields(), isNull);
      expect(validateAddressFields(street: ''), isNull);
    });

    test('requires a postal code of exactly eight digits when present', () {
      expect(validateAddressFields(postalCode: '12345678'), isNull);
      expect(validateAddressFields(postalCode: '1234567'), isNotNull);
      expect(validateAddressFields(postalCode: '123456789'), isNotNull);
      expect(validateAddressFields(postalCode: '12345-678'), isNotNull);
    });

    test('accepts a Brazilian state code and rejects an unknown one', () {
      expect(validateAddressFields(stateCode: 'PE'), isNull);
      expect(validateAddressFields(stateCode: 'SP'), isNull);
      expect(validateAddressFields(stateCode: 'XX'), isNotNull);
      expect(validateAddressFields(stateCode: 'pe'), isNotNull);
    });

    test('rejects overlong optional free text', () {
      expect(validateAddressFields(street: 'a' * 200), isNull);
      expect(validateAddressFields(street: 'a' * 201), isNotNull);
      expect(validateAddressFields(district: 'a' * 100), isNull);
      expect(validateAddressFields(district: 'a' * 101), isNotNull);
      expect(validateAddressFields(city: 'a' * 100), isNull);
      expect(validateAddressFields(city: 'a' * 101), isNotNull);
    });

    test('applies the same length rule to education and marital status', () {
      expect(validateOptionalText('a' * 80, maxLength: 80), isNull);
      expect(validateOptionalText('a' * 81, maxLength: 80), isNotNull);
      expect(validateOptionalText(null, maxLength: 80), isNull);
    });

    test('bounds the session topic at two hundred characters', () {
      expect(
        validateOptionalText('a' * 200, maxLength: sessionTopicMaxLength),
        isNull,
      );
      expect(
        validateOptionalText('a' * 201, maxLength: sessionTopicMaxLength),
        isNotNull,
      );
    });
  });
}
