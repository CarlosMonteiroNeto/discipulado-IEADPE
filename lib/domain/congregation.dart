/// Congregation model (S05).
library;

import 'common.dart';

class Congregation extends DomainRecord {
  const Congregation({
    required this.metadata,
    required this.name,
    required this.normalizedName,
    required this.active,
  });

  @override
  final CommonMetadata metadata;
  final String name;
  final String normalizedName;
  final bool active;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...metadata.toJson(),
    'name': name,
    'normalizedName': normalizedName,
    'active': active,
  };

  factory Congregation.fromJson(JsonMap json) => Congregation(
    metadata: CommonMetadata.fromJson(json),
    name: requireString(json, 'name'),
    normalizedName: requireString(json, 'normalizedName'),
    active: requireBool(json, 'active'),
  );
}
