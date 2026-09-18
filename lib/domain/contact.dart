/// Contact, scope and stable role codes (S05, S06).
library;

import 'common.dart';

enum ContactScope {
  congregation('congregation'),
  supervision('supervision');

  const ContactScope(this.wire);

  final String wire;

  static ContactScope fromWire(String value) => values.firstWhere(
    (scope) => scope.wire == value,
    orElse: () => throw DataFormatException('Unknown contact scope: $value'),
  );
}

/// The twelve stable role codes with their pt-BR labels and owning scope.
enum RoleCode {
  campaignSupervisor(
    'campaignSupervisor',
    'Supervisor das campanhas',
    ContactScope.supervision,
  ),
  campaignDeputy(
    'campaignDeputy',
    'Vice-supervisor das campanhas',
    ContactScope.supervision,
  ),
  discipleshipCoordinator(
    'discipleshipCoordinator',
    'Coordenador do discipulado',
    ContactScope.supervision,
  ),
  discipleshipDeputy(
    'discipleshipDeputy',
    'Vice-coordenador do discipulado',
    ContactScope.supervision,
  ),
  coordinationSecretary(
    'coordinationSecretary',
    'Secretária da coordenação',
    ContactScope.supervision,
  ),
  coordinationDeputySecretary(
    'coordinationDeputySecretary',
    'Vice-secretária da coordenação',
    ContactScope.supervision,
  ),
  congregationAssistant(
    'congregationAssistant',
    'Assistente de congregação',
    ContactScope.congregation,
  ),
  campaignLeader(
    'campaignLeader',
    'Dirigente de campanha',
    ContactScope.congregation,
  ),
  campaignDeputyLeader(
    'campaignDeputyLeader',
    'Vice-dirigente de campanha',
    ContactScope.congregation,
  ),
  teacher('teacher', 'Professor(a) do discipulado', ContactScope.congregation),
  discipleshipSecretary(
    'discipleshipSecretary',
    'Secretária do discipulado',
    ContactScope.congregation,
  ),
  discipleshipDeputySecretary(
    'discipleshipDeputySecretary',
    'Vice-secretária do discipulado',
    ContactScope.congregation,
  );

  const RoleCode(this.wire, this.label, this.scope);

  final String wire;
  final String label;
  final ContactScope scope;

  static RoleCode fromWire(String value) => values.firstWhere(
    (code) => code.wire == value,
    orElse: () => throw DataFormatException('Unknown role code: $value'),
  );
}

class Contact extends DomainRecord {
  const Contact({
    required this.metadata,
    required this.name,
    required this.normalizedName,
    required this.scope,
    required this.congregationId,
    required this.roleCode,
    required this.phoneE164,
    required this.birthDate,
    required this.archived,
  });

  @override
  final CommonMetadata metadata;
  final String name;
  final String normalizedName;
  final ContactScope scope;
  final String? congregationId;
  final RoleCode? roleCode;
  final String? phoneE164;
  final CalendarDate? birthDate;
  final bool archived;

  /// Scope and congregation agree: a supervision contact has no congregation,
  /// a congregational contact has exactly one.
  bool get scopeMatchesCongregation => scope == ContactScope.supervision
      ? congregationId == null
      : congregationId != null;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...metadata.toJson(),
    'name': name,
    'normalizedName': normalizedName,
    'scope': scope.wire,
    'congregationId': congregationId,
    'roleCode': roleCode?.wire,
    'phoneE164': phoneE164,
    'birthDate': birthDate?.toIso8601String(),
    'archived': archived,
  };

  factory Contact.fromJson(JsonMap json) {
    final scope = requireString(json, 'scope');
    final roleCode = optionalString(json, 'roleCode');
    return Contact(
      metadata: CommonMetadata.fromJson(json),
      name: requireString(json, 'name'),
      normalizedName: requireString(json, 'normalizedName'),
      scope: ContactScope.fromWire(scope),
      congregationId: optionalString(json, 'congregationId'),
      roleCode: roleCode == null ? null : RoleCode.fromWire(roleCode),
      phoneE164: optionalString(json, 'phoneE164'),
      birthDate: decodeCalendarDate(json['birthDate']),
      archived: requireBool(json, 'archived'),
    );
  }
}
