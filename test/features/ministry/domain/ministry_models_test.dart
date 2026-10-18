import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';

void main() {
  group('MinistryRecord and Student boundary decoding', () {
    test(
      'decodes valid student while keeping source ID distinct from UUID',
      () {
        final student = Student.fromJson(<String, Object?>{
          'id': '123e4567-e89b-42d3-a456-426614174000',
          'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
          'revision': 3,
          'created_at': '2026-10-16T12:00:00Z',
          'updated_at': '2026-10-16T12:30:00-03:00',
          'updated_by': '123e4567-e89b-42d3-a456-426614174002',
          'legacy_firebase_id': 'old-student-17',
          'name': 'Ana Silva',
          'normalized_name': 'ana silva',
          'phone_e164': null,
          'birth_date': '2010-02-28',
          'address': null,
          'education': null,
          'marital_status': null,
          'new_convert': null,
          'water_baptized': null,
          'wants_baptism': null,
          'archived': false,
          'convert_id': null,
        });

        expect(student.metadata.id, '123e4567-e89b-42d3-a456-426614174000');
        expect(student.metadata.legacyFirebaseId, 'old-student-17');
        expect(student.metadata.id, isNot(student.metadata.legacyFirebaseId));
        expect(student.birthDate!.toString(), '2010-02-28');
        expect(student.waterBaptized, isNull);
        expect(student.wantsBaptism, isNull);
        expect(student.metadata.toJson()['id'], student.metadata.id);
      },
    );

    test('rejects an impossible date-only value', () {
      expect(
        () => CalendarDate.parse('2026-02-30'),
        throwsA(isA<MinistryDataException>()),
      );
    });

    test('rejects an unknown status wire value', () {
      expect(
        () => ClassStatus.fromWire('in_progress'),
        throwsA(isA<MinistryDataException>()),
      );
    });

    test('rejects congregation contact without congregation UUID', () {
      expect(
        () => MinistryContact.fromJson(<String, Object?>{
          ..._metadata(),
          'name': 'João',
          'normalized_name': 'joao',
          'scope': 'congregation',
          'congregation_id': null,
          'role_code': 'teacher',
          'phone_e164': null,
          'birth_date': null,
          'archived': false,
        }),
        throwsA(isA<MinistryDataException>()),
      );
    });

    test('rejects a supervision role on a congregation contact', () {
      expect(
        () => MinistryContact.fromJson(<String, Object?>{
          ..._metadata(),
          'name': 'João',
          'normalized_name': 'joao',
          'scope': 'congregation',
          'role_code': 'campaignSupervisor',
          'phone_e164': null,
          'birth_date': null,
          'archived': false,
        }),
        throwsA(isA<MinistryDataException>()),
      );
    });

    test('rejects contradictory baptism answers', () {
      expect(
        () => Student.fromJson(<String, Object?>{
          ..._metadata(),
          'name': 'Ana Silva',
          'normalized_name': 'ana silva',
          'phone_e164': null,
          'birth_date': null,
          'address': null,
          'education': null,
          'marital_status': null,
          'new_convert': null,
          'water_baptized': true,
          'wants_baptism': true,
          'archived': false,
          'convert_id': null,
        }),
        throwsA(isA<MinistryDataException>()),
      );
    });

    test('rejects unknown persisted fields at the model boundary', () {
      expect(
        () => Student.fromJson(<String, Object?>{
          ..._metadata(),
          'name': 'Ana Silva',
          'normalized_name': 'ana silva',
          'phone_e164': null,
          'birth_date': null,
          'address': null,
          'education': null,
          'marital_status': null,
          'new_convert': null,
          'water_baptized': null,
          'wants_baptism': null,
          'archived': false,
          'convert_id': null,
          'surprise': true,
        }),
        throwsA(isA<MinistryDataException>()),
      );
    });
  });
}

Map<String, Object?> _metadata() => <String, Object?>{
  'id': '123e4567-e89b-42d3-a456-426614174000',
  'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
  'revision': 1,
  'created_at': '2026-10-16T12:00:00Z',
  'updated_at': '2026-10-16T12:00:00Z',
  'updated_by': '123e4567-e89b-42d3-a456-426614174002',
  'legacy_firebase_id': null,
};
