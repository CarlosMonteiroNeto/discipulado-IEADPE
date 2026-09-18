/// Access profile and session types (S04, S11).
library;

import 'common.dart';

enum AccessRole {
  supervisor('supervisor'),
  congregationStaff('congregationStaff');

  const AccessRole(this.wire);

  final String wire;

  static AccessRole fromWire(String value) => values.firstWhere(
    (role) => role.wire == value,
    orElse: () => throw DataFormatException('Unknown access role: $value'),
  );
}

/// The validated `users/{uid}` profile carried by [AuthSession].
class AccessProfile {
  const AccessProfile({
    required this.accessRole,
    required this.congregationId,
    required this.active,
    required this.revision,
    required this.updatedAt,
  });

  final AccessRole accessRole;
  final String? congregationId;
  final bool active;
  final int revision;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'accessRole': accessRole.wire,
    'congregationId': congregationId,
    'active': active,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory AccessProfile.fromJson(JsonMap json) {
    final role = json['accessRole'];
    if (role is! String) {
      throw const DataFormatException('Missing access role.');
    }
    final congregationId = json['congregationId'];
    if (congregationId != null && congregationId is! String) {
      throw const DataFormatException('Invalid congregation id.');
    }
    final active = json['active'];
    if (active is! bool) {
      throw const DataFormatException('Missing active flag.');
    }
    final revision = json['revision'];
    if (revision is! int) {
      throw const DataFormatException('Missing profile revision.');
    }
    final updatedAt = json['updatedAt'];
    if (updatedAt is! String) {
      throw const DataFormatException('Missing updatedAt.');
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) {
      throw const DataFormatException('Invalid updatedAt.');
    }
    return AccessProfile(
      accessRole: AccessRole.fromWire(role),
      congregationId: congregationId as String?,
      active: active,
      revision: revision,
      updatedAt: parsedUpdatedAt.toUtc(),
    );
  }
}

class AuthSession {
  const AuthSession({required this.uid, required this.profile});

  final String uid;
  final AccessProfile profile;
}
