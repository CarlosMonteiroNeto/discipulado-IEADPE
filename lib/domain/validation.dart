/// Pure Dart validation shared with the backend (S05).
///
/// The same deterministic normalization and calendar semantics must be
/// repeated server-side; the backend is authoritative.
library;

import 'common.dart';

const int nameMinLength = 2;
const int nameMaxLength = 120;
const int addressStreetMaxLength = 200;
const int addressDistrictMaxLength = 100;
const int addressCityMaxLength = 100;
const int optionalTextMaxLength = 80;
const int sessionTopicMaxLength = 200;

/// Minimum accepted birth date (S05).
const int minimumBirthYear = 1900;

/// America/Recife has been UTC-3 without DST since 2019.
const Duration recifeUtcOffset = Duration(hours: -3);

const Set<String> brazilianStateCodes = <String>{
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
};

const Map<String, String> _diacriticFold = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'į': 'i',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ő': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ű': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'š': 's',
  'ś': 's',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
  'đ': 'd',
  'ğ': 'g',
  'ł': 'l',
  'ť': 't',
  'ř': 'r',
};

/// Deterministic search key: trim, lowercase and remove diacritics.
String normalizeName(String displayName) {
  final buffer = StringBuffer();
  for (final unit in displayName.trim().toLowerCase().runes) {
    final character = String.fromCharCode(unit);
    buffer.write(_diacriticFold[character] ?? character);
  }
  return buffer.toString();
}

/// Null when the trimmed display name length is within 2..120, else an error.
String? validateDisplayName(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.length < nameMinLength) {
    return 'O nome deve ter pelo menos $nameMinLength caracteres.';
  }
  if (trimmed.length > nameMaxLength) {
    return 'O nome deve ter no máximo $nameMaxLength caracteres.';
  }
  return null;
}

/// Null for empty optional text; an error when longer than [maxLength].
String? validateOptionalText(String? value, {required int maxLength}) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length > maxLength) {
    return 'O texto deve ter no máximo $maxLength caracteres.';
  }
  return null;
}

/// Normalizes an optional Brazilian number to E.164. Empty input yields null.
/// Throws [FormatException] for malformed structure.
String? normalizeBrazilianPhone(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  if (RegExp(r'[A-Za-z]').hasMatch(trimmed)) {
    throw const FormatException('Telefone inválido.');
  }
  if (RegExp(r'[^0-9+()\-.\s]').hasMatch(trimmed)) {
    throw const FormatException('Telefone inválido.');
  }

  String digits;
  if (trimmed.startsWith('+')) {
    if (!trimmed.startsWith('+55')) {
      throw const FormatException('Apenas números brasileiros são aceitos.');
    }
    digits = trimmed.substring(3).replaceAll(RegExp(r'[^0-9]'), '');
  } else {
    if (trimmed.contains('+')) {
      throw const FormatException('Telefone inválido.');
    }
    digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  if (digits.length != 10 && digits.length != 11) {
    throw const FormatException('Telefone deve ter 10 ou 11 dígitos.');
  }
  if (digits[0] == '0') {
    throw const FormatException('DDD inválido.');
  }
  if (digits.length == 11 && digits[2] != '9') {
    throw const FormatException('Celular deve começar com 9.');
  }
  return '+55$digits';
}

/// Null when the optional phone is empty or well-formed, else an error.
String? validatePhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    normalizeBrazilianPhone(raw);
    return null;
  } on FormatException catch (error) {
    return error.message;
  }
}

/// The current calendar date in America/Recife for a UTC instant.
CalendarDate recifeToday(DateTime nowUtc) {
  final local = nowUtc.toUtc().add(recifeUtcOffset);
  return CalendarDate(local.year, local.month, local.day);
}

/// Null for an empty optional birth date; rejects before 1900 or after today
/// in America/Recife. There is no rolling minimum age.
String? validateBirthDate(CalendarDate? date, {required DateTime nowUtc}) {
  if (date == null) return null;
  final minimum = CalendarDate(minimumBirthYear, 1, 1);
  if (date.compareTo(minimum) < 0) {
    return 'A data de nascimento deve ser a partir de 01/01/$minimumBirthYear.';
  }
  if (date.compareTo(recifeToday(nowUtc)) > 0) {
    return 'A data de nascimento não pode estar no futuro.';
  }
  return null;
}

/// Null when the nullable religious answers are consistent. Baptized and
/// wanting baptism cannot both be true; null means not informed.
String? validateBaptismAnswers({bool? waterBaptized, bool? wantsBaptism}) {
  if (waterBaptized == true && wantsBaptism == true) {
    return 'Quem já foi batizado não pode desejar o batismo.';
  }
  return null;
}

/// Validates optional address fields; empty or absent fields are accepted.
String? validateAddressFields({
  String? street,
  String? district,
  String? city,
  String? postalCode,
  String? stateCode,
}) {
  final streetError = validateOptionalText(
    street,
    maxLength: addressStreetMaxLength,
  );
  if (streetError != null) return streetError;

  final districtError = validateOptionalText(
    district,
    maxLength: addressDistrictMaxLength,
  );
  if (districtError != null) return districtError;

  final cityError = validateOptionalText(city, maxLength: addressCityMaxLength);
  if (cityError != null) return cityError;

  if (postalCode != null && postalCode.trim().isNotEmpty) {
    if (!RegExp(r'^\d{8}$').hasMatch(postalCode.trim())) {
      return 'O CEP deve ter exatamente 8 dígitos.';
    }
  }

  if (stateCode != null && stateCode.trim().isNotEmpty) {
    if (!brazilianStateCodes.contains(stateCode.trim())) {
      return 'UF inválida.';
    }
  }
  return null;
}
