import '../../../domain/uuid_shape.dart';

/// Immutable identity of a session opened from a class's own session list.
class SessionNavigationContext {
  SessionNavigationContext({
    required this.congregationId,
    required this.classId,
    required this.sessionId,
  }) {
    for (final (name, value) in <(String, String)>[
      ('congregationId', congregationId),
      ('classId', classId),
      ('sessionId', sessionId),
    ]) {
      if (!_uuid.hasMatch(value)) {
        throw ArgumentError.value(value, name, 'Must be a UUID.');
      }
    }
  }

  static final RegExp _uuid = uuidShapePattern;

  final String congregationId;
  final String classId;
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      other is SessionNavigationContext &&
      other.congregationId == congregationId &&
      other.classId == classId &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(congregationId, classId, sessionId);
}
