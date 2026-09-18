/// Student and address models (S05).
library;

import 'common.dart';
import 'validation.dart';

class Address {
  const Address({
    required this.street,
    required this.district,
    required this.city,
    required this.postalCode,
    required this.stateCode,
  });

  final String? street;
  final String? district;
  final String? city;
  final String? postalCode;
  final String? stateCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'street': street,
    'district': district,
    'city': city,
    'postalCode': postalCode,
    'stateCode': stateCode,
  };

  factory Address.fromJson(JsonMap json) => Address(
    street: optionalString(json, 'street'),
    district: optionalString(json, 'district'),
    city: optionalString(json, 'city'),
    postalCode: optionalString(json, 'postalCode'),
    stateCode: optionalString(json, 'stateCode'),
  );
}

class Student extends DomainRecord {
  const Student({
    required this.metadata,
    required this.name,
    required this.normalizedName,
    required this.congregationId,
    required this.phoneE164,
    required this.birthDate,
    required this.address,
    required this.education,
    required this.maritalStatus,
    required this.newConvert,
    required this.waterBaptized,
    required this.wantsBaptism,
    required this.archived,
  });

  @override
  final CommonMetadata metadata;
  final String name;
  final String normalizedName;
  final String congregationId;
  final String? phoneE164;
  final CalendarDate? birthDate;
  final Address? address;
  final String? education;
  final String? maritalStatus;
  final bool? newConvert;
  final bool? waterBaptized;
  final bool? wantsBaptism;
  final bool archived;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...metadata.toJson(),
    'name': name,
    'normalizedName': normalizedName,
    'congregationId': congregationId,
    'phoneE164': phoneE164,
    'birthDate': birthDate?.toIso8601String(),
    'address': address?.toJson(),
    'education': education,
    'maritalStatus': maritalStatus,
    'newConvert': newConvert,
    'waterBaptized': waterBaptized,
    'wantsBaptism': wantsBaptism,
    'archived': archived,
  };

  factory Student.fromJson(JsonMap json) {
    final waterBaptized = optionalBool(json, 'waterBaptized');
    final wantsBaptism = optionalBool(json, 'wantsBaptism');
    final contradiction = validateBaptismAnswers(
      waterBaptized: waterBaptized,
      wantsBaptism: wantsBaptism,
    );
    if (contradiction != null) {
      throw DataFormatException(contradiction);
    }
    final rawAddress = decodeJsonMap(json['address']);
    return Student(
      metadata: CommonMetadata.fromJson(json),
      name: requireString(json, 'name'),
      normalizedName: requireString(json, 'normalizedName'),
      congregationId: requireString(json, 'congregationId'),
      phoneE164: optionalString(json, 'phoneE164'),
      birthDate: decodeCalendarDate(json['birthDate']),
      address: rawAddress == null ? null : Address.fromJson(rawAddress),
      education: optionalString(json, 'education'),
      maritalStatus: optionalString(json, 'maritalStatus'),
      newConvert: optionalBool(json, 'newConvert'),
      waterBaptized: waterBaptized,
      wantsBaptism: wantsBaptism,
      archived: requireBool(json, 'archived'),
    );
  }
}
