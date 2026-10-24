/// The textual `uuid` shape PostgreSQL accepts: five hex groups of
/// 8-4-4-4-12 digits.
///
/// The RFC 4122 version and variant nibbles are intentionally **not**
/// constrained. PostgreSQL stores and returns such values as valid `uuid`s, and
/// imported records can carry them, so rejecting them client-side turns a
/// readable row into an `invalid_response` failure. Identity and authorisation
/// are decided by the server; the client only checks that the value is a uuid.
final RegExp uuidShapePattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Returns `true` for any value PostgreSQL would accept as a `uuid`.
bool isUuidShape(String value) => uuidShapePattern.hasMatch(value);
