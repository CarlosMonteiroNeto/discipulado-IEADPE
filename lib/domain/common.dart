/// Shared pure Dart domain primitives.
library;

typedef JsonMap = Map<String, Object?>;

/// Thrown when persisted data cannot be decoded into a domain value
/// (unknown enum wire values, malformed embedded structures, or a stored
/// invariant violation). Callers translate it into a safe `AppFailure`
/// instead of crashing.
class DataFormatException implements Exception {
  const DataFormatException(this.message);

  final String message;

  @override
  String toString() => 'DataFormatException: $message';
}

/// Metadata shared by every mutable domain document (S05).
class CommonMetadata {
  const CommonMetadata({
    required this.id,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedBy;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'revision': revision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'updatedBy': updatedBy,
  };

  factory CommonMetadata.fromJson(JsonMap json) => CommonMetadata(
    id: requireString(json, 'id'),
    revision: requireInt(json, 'revision'),
    createdAt: _requiredUtcTimestamp(json, 'createdAt'),
    updatedAt: _requiredUtcTimestamp(json, 'updatedAt'),
    updatedBy: requireString(json, 'updatedBy'),
  );
}

/// Base for every mutable domain document: stable id, integer revision and
/// UTC event timestamps.
abstract class DomainRecord {
  const DomainRecord();

  CommonMetadata get metadata;

  String get id => metadata.id;

  int get revision => metadata.revision;

  DateTime get createdAt => metadata.createdAt;

  DateTime get updatedAt => metadata.updatedAt;

  String get updatedBy => metadata.updatedBy;

  Map<String, Object?> toJson();
}

/// ISO date-only calendar date with no timezone conversion (S05).
///
/// Storage and transport use `yyyy-MM-dd`; there is no implicit UTC shift
/// because the value never passes through a [DateTime] in a local zone.
class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate._(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory CalendarDate(int year, int month, int day) {
    if (!isValid(year, month, day)) {
      throw FormatException('Invalid calendar date: $year-$month-$day');
    }
    return CalendarDate._(year, month, day);
  }

  factory CalendarDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid ISO calendar date: $value');
    }
    return CalendarDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static CalendarDate? tryParse(String? value) {
    if (value == null) return null;
    try {
      return CalendarDate.parse(value);
    } on FormatException {
      return null;
    }
  }

  factory CalendarDate.fromDateTime(DateTime value) =>
      CalendarDate(value.year, value.month, value.day);

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static int daysInMonth(int year, int month) {
    switch (month) {
      case 1:
      case 3:
      case 5:
      case 7:
      case 8:
      case 10:
      case 12:
        return 31;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      case 2:
        return isLeapYear(year) ? 29 : 28;
      default:
        return 0;
    }
  }

  static bool isValid(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > daysInMonth(year, month)) return false;
    return true;
  }

  /// The same date at UTC midnight; used only for ordering/formatting, never
  /// to derive the stored day.
  DateTime toDateTime() => DateTime.utc(year, month, day);

  String toIso8601String() {
    final buffer = StringBuffer();
    buffer.write(year.toString().padLeft(4, '0'));
    buffer.write('-');
    buffer.write(month.toString().padLeft(2, '0'));
    buffer.write('-');
    buffer.write(day.toString().padLeft(2, '0'));
    return buffer.toString();
  }

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso8601String();
}

String requireString(JsonMap json, String key) {
  final value = json[key];
  if (value is! String) {
    throw DataFormatException('Missing or invalid string field "$key".');
  }
  return value;
}

int requireInt(JsonMap json, String key) {
  final value = json[key];
  if (value is! int) {
    throw DataFormatException('Missing or invalid integer field "$key".');
  }
  return value;
}

bool requireBool(JsonMap json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw DataFormatException('Missing or invalid boolean field "$key".');
  }
  return value;
}

String? optionalString(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw DataFormatException('Invalid optional string field "$key".');
}

bool? optionalBool(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw DataFormatException('Invalid optional boolean field "$key".');
}

int? optionalInt(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw DataFormatException('Invalid optional integer field "$key".');
}

DateTime _requiredUtcTimestamp(JsonMap json, String key) {
  final value = json[key];
  if (value is! String) {
    throw DataFormatException('Missing or invalid timestamp field "$key".');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw DataFormatException('Invalid timestamp field "$key": $value');
  }
  return parsed.toUtc();
}

/// Shared decoding helpers used by the domain models.
JsonMap? decodeJsonMap(Object? raw) {
  if (raw == null) return null;
  if (raw is Map) return Map<String, Object?>.from(raw);
  throw const DataFormatException('Expected a JSON object.');
}

bool? decodeBool(Object? raw) {
  if (raw == null) return null;
  if (raw is bool) return raw;
  throw const DataFormatException('Expected a boolean value.');
}

CalendarDate? decodeCalendarDate(Object? raw) {
  if (raw == null) return null;
  if (raw is String) {
    final parsed = CalendarDate.tryParse(raw);
    if (parsed != null) return parsed;
  }
  throw DataFormatException('Expected an ISO calendar date, got: $raw');
}
