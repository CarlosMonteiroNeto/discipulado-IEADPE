/// Returns a display name from session metadata without deriving authority.
String? sessionDisplayName(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  for (final key in const ['full_name', 'name']) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
