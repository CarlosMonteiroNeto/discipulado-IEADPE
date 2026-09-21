/// Brazilian phone input mask ported from perfume-pos: digits only, 11
/// positions, rendered as `(XX) XXXXX-XXXX` while typing.
library;

import 'package:flutter/services.dart';

const int _maxDigits = 11;
const String _countryCode = '55';

/// Returns only the digits of [raw], preserving their order.
String phoneDigits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

/// Renders [raw] as the Brazilian mobile mask `(XX) XXXXX-XXXX`,
/// progressively, using at most the first 11 digits.
String formatPhone(String raw) {
  final capped = _cappedDigits(raw);
  if (capped.isEmpty) return '';

  final area = capped.length < 2 ? capped : capped.substring(0, 2);
  if (capped.length <= 2) return '($area';

  final local = capped.substring(2);
  final buffer = StringBuffer('($area) ');
  if (local.length <= 5) {
    buffer.write(local);
  } else {
    buffer.write(local.substring(0, 5));
    buffer.write('-');
    buffer.write(local.substring(5));
  }
  return buffer.toString();
}

/// True only when [raw] carries exactly 11 digits.
bool isValidPhone(String raw) => phoneDigits(raw).length == _maxDigits;

String _cappedDigits(String raw) {
  var digits = phoneDigits(raw);
  // A pasted country code (+55) is not part of the number: drop it so the area
  // code lands in the first two slots. Only when the run is longer than a full
  // number, so a genuine 11-digit number starting with 55 is left untouched.
  if (digits.length > _maxDigits && digits.startsWith(_countryCode)) {
    digits = digits.substring(_countryCode.length);
  }
  return digits.length > _maxDigits ? digits.substring(0, _maxDigits) : digits;
}

int _strippedCountryDigits(String raw) {
  final digits = phoneDigits(raw);
  return digits.length > _maxDigits && digits.startsWith(_countryCode)
      ? _countryCode.length
      : 0;
}

int _offsetAfterDigits(String text, int digitCount) {
  if (digitCount <= 0) return 0;
  var seen = 0;
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code >= 0x30 && code <= 0x39) {
      seen++;
      if (seen == digitCount) return i + 1;
    }
  }
  return text.length;
}

/// [TextInputFormatter] that blocks non-digits, drops a pasted country code,
/// caps at 11 digits and masks the value as `(XX) XXXXX-XXXX` while typing. The
/// caret is kept after the edited digit so a mid-string edit does not jump to
/// the end.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatPhone(newValue.text);
    final selection = newValue.selection;
    final cursor = selection.baseOffset;
    // A range selection (or no selection) collapses to the end.
    if (cursor < 0 || cursor != selection.extentOffset) {
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    if (cursor >= newValue.text.length) {
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    final digitsBefore = phoneDigits(newValue.text.substring(0, cursor)).length;
    final target = (digitsBefore - _strippedCountryDigits(newValue.text)).clamp(
      0,
      _maxDigits,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetAfterDigits(formatted, target),
      ),
    );
  }
}