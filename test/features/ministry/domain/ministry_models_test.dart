import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_codec.dart';
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
          'person_id': null,
          'person_revision': null,
        });

        expect(student.metadata.id, '123e4567-e89b-42d3-a456-426614174000');
        expect(student.metadata.legacyFirebaseId, 'old-student-17');
        expect(student.metadata.id, isNot(student.metadata.legacyFirebaseId));
        expect(student.birthDate!.toString(), '2010-02-28');
        expect(student.waterBaptized, isNull);
        expect(student.wantsBaptism, isNull);
        expect(student.personId, isNull);
        expect(student.personRevision, isNull);
        expect(student.metadata.toJson()['id'], student.metadata.id);
      },
    );

    test('decodes canonical person with unknown migrated attribution', () {
      final person = MinistryPerson.fromJson(<String, Object?>{
        'id': '123e4567-e89b-42d3-a456-426614174010',
        'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
        'name': 'Ana Silva',
        'normalized_name': 'ana silva',
        'phone': '+5511999990000',
        'birth_date': '1990-02-28',
        'address': {
          'street': 'Rua A',
          'district': null,
          'city': null,
          'postal_code': null,
          'state_code': null,
        },
        'created_at': '2026-10-16T12:00:00Z',
        'updated_at': '2026-10-16T12:30:00Z',
        'updated_by': null,
      }, revision: 4);

      expect(person.id, '123e4567-e89b-42d3-a456-426614174010');
      expect(person.revision, 4);
      expect(person.updatedBy, isNull);
      expect(person.address?.street, 'Rua A');
      expect(person.birthDate.toString(), '1990-02-28');
    });

    test(
      'get_person decoder accepts a legacy canonical name over 200 chars',
      () {
        final name = List.filled(201, 'A').join();
        final person = decodeMinistryPersonDetail({
          'person': {
            'id': '123e4567-e89b-42d3-a456-426614174010',
            'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
            'name': name,
            'normalized_name': name.toLowerCase(),
            'phone': null,
            'birth_date': null,
            'address': null,
            'created_at': '2026-10-16T12:00:00Z',
            'updated_at': '2026-10-16T12:00:00Z',
            'updated_by': null,
          },
          'person_revision': 1,
        });

        expect(person.name, name);
      },
    );

    test(
      'list_people decoder accepts a legacy canonical name over 200 chars',
      () {
        final name = List.filled(201, 'A').join();
        final page = decodePeoplePage({
          'items': [
            {
              'id': '123e4567-e89b-42d3-a456-426614174010',
              'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
              'name': name,
              'normalized_name': name.toLowerCase(),
              'phone': null,
              'birth_date': null,
              'address': null,
              'person_revision': 1,
            },
          ],
          'next_cursor': null,
        });

        expect(page.items.single.name, name);
      },
    );

    test('list_people preserves blank and whitespace phone strings', () {
      final page = decodePeoplePage({
        'items': [
          {
            'id': '123e4567-e89b-42d3-a456-426614174010',
            'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
            'name': 'Ana Silva',
            'normalized_name': 'ana silva',
            'phone': '',
            'birth_date': null,
            'address': null,
            'person_revision': 1,
          },
          {
            'id': '123e4567-e89b-42d3-a456-426614174011',
            'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
            'name': 'Bia Silva',
            'normalized_name': 'bia silva',
            'phone': '   ',
            'birth_date': null,
            'address': null,
            'person_revision': 1,
          },
        ],
        'next_cursor': null,
      });

      expect(page.items.map((person) => person.phone), ['', '   ']);
    });

    test('list_people rejects non-string phone values', () {
      expect(
        () => decodePeoplePage({
          'items': [
            {
              'id': '123e4567-e89b-42d3-a456-426614174010',
              'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
              'name': 'Ana Silva',
              'normalized_name': 'ana silva',
              'phone': 123,
              'birth_date': null,
              'address': null,
              'person_revision': 1,
            },
          ],
          'next_cursor': null,
        }),
        throwsA(isA<MinistryDataException>()),
      );
    });

    test(
      'list_students model accepts a legacy canonical name over 200 chars',
      () {
        final name = List.filled(201, 'A').join();
        final student = Student.fromJson({
          ..._metadata(),
          'name': name,
          'normalized_name': name.toLowerCase(),
          'phone_e164': null,
          'birth_date': null,
          'address': null,
          'education': null,
          'marital_status': null,
          'new_convert': null,
          'water_baptized': null,
          'wants_baptism': null,
          'archived': false,
          'person_id': '123e4567-e89b-42d3-a456-426614174010',
          'person_revision': 1,
        });

        expect(student.name, name);
      },
    );

    test(
      'class roster decoder accepts a legacy canonical name over 200 chars',
      () {
        final name = List.filled(201, 'A').join();
        final page = decodeClassStudents({
          'items': [
            {
              'student': {
                'id': '123e4567-e89b-42d3-a456-426614174020',
                'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
                'name': name,
                'normalized_name': name.toLowerCase(),
                'phone_e164': null,
                'birth_date': null,
                'address': null,
                'education': null,
                'marital_status': null,
                'new_convert': null,
                'water_baptized': null,
                'wants_baptism': null,
                'archived_at': null,
                'person_id': '123e4567-e89b-42d3-a456-426614174010',
                'revision': 1,
                'person_revision': 1,
                'created_at': '2026-10-16T12:00:00Z',
                'updated_at': '2026-10-16T12:00:00Z',
                'updated_by': '123e4567-e89b-42d3-a456-426614174002',
              },
              'enrollment': {
                'id': '123e4567-e89b-42d3-a456-426614174030',
                'congregation_id': '123e4567-e89b-42d3-a456-426614174001',
                'student_id': '123e4567-e89b-42d3-a456-426614174020',
                'class_id': '123e4567-e89b-42d3-a456-426614174040',
                'start_date': '2026-10-01',
                'end_date': null,
                'status': 'active',
                'revision': 1,
                'created_at': '2026-10-16T12:00:00Z',
                'updated_at': '2026-10-16T12:00:00Z',
                'updated_by': '123e4567-e89b-42d3-a456-426614174002',
              },
            },
          ],
          'next_cursor': null,
        });

        expect(page.items.single.student.name, name);
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
