/// Pure Brazilian input helpers shared by forms and tests.
///
/// Display values are local; phone values are normalized to E.164 only when a
/// form submits a valid number. Dates are always exchanged as ISO date-only
/// strings with the backend.
library;

String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

String _two(int value) => value.toString().padLeft(2, '0');

/// Returns the national 11-digit phone number, accepting a leading +55.
String brPhoneNationalDigits(String value) {
  var digits = _digits(value);
  if (digits.length == 13 && digits.startsWith('55')) {
    digits = digits.substring(2);
  } else if (digits.length == 12 && digits.startsWith('55')) {
    digits = digits.substring(2);
  }
  return digits.length > 11 ? digits.substring(0, 11) : digits;
}

/// Formats a phone progressively as `(XX) X XXXX-XXXX`.
String formatBrPhone(String value) {
  final digits = brPhoneNationalDigits(value);
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '($digits';

  final buffer = StringBuffer('(${digits.substring(0, 2)}) ');
  buffer.write(digits[2]);
  if (digits.length > 3) {
    final middleEnd = digits.length > 7 ? 7 : digits.length;
    buffer
      ..write(' ')
      ..write(digits.substring(3, middleEnd));
  }
  if (digits.length > 7) {
    buffer
      ..write('-')
      ..write(digits.substring(7));
  }
  return buffer.toString();
}

/// Formats a stored value for display without discarding an unparseable legacy
/// value.
String brPhoneDisplay(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '';
  final digits = brPhoneNationalDigits(text);
  return digits.length == 11 ? formatBrPhone(digits) : text;
}

String? brPhoneValidationError(String? value, {bool required = false}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'Informe o telefone.' : null;
  final digits = brPhoneNationalDigits(text);
  if (digits.length != 11) return 'O telefone deve ter 11 dígitos.';
  final ddd = int.tryParse(digits.substring(0, 2));
  if (ddd == null || ddd < 11) return 'Informe um DDD válido.';
  return null;
}

String? brPhoneE164(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty || brPhoneValidationError(text) != null) return null;
  return '+55${brPhoneNationalDigits(text)}';
}

/// Normalizes every valid Brazilian phone to E.164 for storage, including an
/// unchanged national-format value loaded from a legacy record.
String? resolveBrPhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return brPhoneE164(text);
}

String formatBrDate(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year.toString().padLeft(4, '0')}';

String brDateIso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}';

DateTime? _validatedDate(int year, int month, int day) {
  final value = DateTime(year, month, day);
  return value.year == year && value.month == month && value.day == day
      ? value
      : null;
}

DateTime? parseBrDate(String? value) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$')
      .firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  return _validatedDate(
    int.parse(match.group(3)!),
    int.parse(match.group(2)!),
    int.parse(match.group(1)!),
  );
}

DateTime? parseDateInput(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final display = parseBrDate(text);
  if (display != null) return display;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T\s].*)?$')
      .firstMatch(text);
  if (match == null) return null;
  return _validatedDate(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

String brDateDisplay(String? value) {
  final parsed = parseDateInput(value);
  return parsed == null ? (value?.trim() ?? '') : formatBrDate(parsed);
}

String? brDateValidationError(String? value, {bool required = false}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'Informe a data.' : null;
  return parseDateInput(text) == null ? 'Informe uma data válida.' : null;
}
