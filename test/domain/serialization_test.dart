import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/class_group.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/congregation.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/enrollment.dart';
import 'package:discipulado_ieadpe/domain/session.dart';
import 'package:discipulado_ieadpe/domain/student.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('CommonMetadata', () {
    test('round-trips UTC instants without changing them', () {
      final metadata = CommonMetadata(
        id: 'cong-1',
        revision: 3,
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        updatedAt: DateTime.utc(2026, 2, 3, 4, 5, 6),
        updatedBy: 'uid-1',
      );

      final json = metadata.toJson();
      expect(json['id'], 'cong-1');
      expect(json['revision'], 3);
      expect(json['createdAt'], '2026-01-02T03:04:05.000Z');
      expect(json['updatedAt'], '2026-02-03T04:05:06.000Z');
      expect(json['updatedBy'], 'uid-1');

      final decoded = CommonMetadata.fromJson(json);
      expect(decoded.id, 'cong-1');
      expect(decoded.revision, 3);
      expect(decoded.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(decoded.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(decoded.updatedBy, 'uid-1');
    });
  });

  group('Congregation', () {
    test('round-trips its fields', () {
      final congregation = Congregation(
        metadata: meta(id: 'cong-1'),
        name: 'Central',
        normalizedName: 'central',
        active: true,
      );

      final json = congregation.toJson();
      expect(json['id'], 'cong-1');
      expect(json['name'], 'Central');
      expect(json['normalizedName'], 'central');
      expect(json['active'], true);

      final decoded = Congregation.fromJson(json);
      expect(decoded.id, 'cong-1');
      expect(decoded.name, 'Central');
      expect(decoded.normalizedName, 'central');
      expect(decoded.active, true);
      expect(decoded.revision, 1);
    });
  });

  group('Contact', () {
    test('round-trips scope, role and optional phone', () {
      final contact = Contact(
        metadata: meta(id: 'ct-1'),
        name: 'João da Silva',
        normalizedName: 'joao da silva',
        scope: ContactScope.congregation,
        congregationId: 'cong-1',
        roleCode: RoleCode.teacher,
        phoneE164: '+5581999999999',
        birthDate: CalendarDate(1980, 5, 4),
        archived: false,
      );

      final json = contact.toJson();
      expect(json['scope'], 'congregation');
      expect(json['roleCode'], 'teacher');
      expect(json['phoneE164'], '+5581999999999');
      expect(json['birthDate'], '1980-05-04');
      expect(json['archived'], false);

      final decoded = Contact.fromJson(json);
      expect(decoded.name, 'João da Silva');
      expect(decoded.scope, ContactScope.congregation);
      expect(decoded.roleCode, RoleCode.teacher);
      expect(decoded.congregationId, 'cong-1');
      expect(decoded.phoneE164, '+5581999999999');
      expect(decoded.birthDate, CalendarDate(1980, 5, 4));
    });

    test('keeps absent optional fields explicit as null', () {
      final json = Contact(
        metadata: meta(),
        name: 'Ana',
        normalizedName: 'ana',
        scope: ContactScope.supervision,
        congregationId: null,
        roleCode: null,
        phoneE164: null,
        birthDate: null,
        archived: false,
      ).toJson();

      expect(json.containsKey('congregationId'), isTrue);
      expect(json['congregationId'], isNull);
      expect(json.containsKey('roleCode'), isTrue);
      expect(json['roleCode'], isNull);
      expect(json['birthDate'], isNull);
    });

    test('rejects an unknown role code as a controlled data error', () {
      final json = <String, Object?>{
        'id': 'ct-1',
        'revision': 1,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'updatedBy': 'uid-1',
        'name': 'Ana',
        'normalizedName': 'ana',
        'scope': 'congregation',
        'congregationId': 'cong-1',
        'roleCode': 'wizard',
        'phoneE164': null,
        'birthDate': null,
        'archived': false,
      };

      expect(() => Contact.fromJson(json), throwsA(isA<DataFormatException>()));
    });

    test('rejects an unknown contact scope as a controlled data error', () {
      final json = <String, Object?>{
        'id': 'ct-1',
        'revision': 1,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'updatedBy': 'uid-1',
        'name': 'Ana',
        'normalizedName': 'ana',
        'scope': 'regional',
        'congregationId': null,
        'roleCode': null,
        'phoneE164': null,
        'birthDate': null,
        'archived': false,
      };

      expect(() => Contact.fromJson(json), throwsA(isA<DataFormatException>()));
    });
  });

  group('AccessProfile', () {
    test('round-trips the validated access profile', () {
      final profile = AccessProfile(
        accessRole: AccessRole.congregationStaff,
        congregationId: 'cong-1',
        active: true,
        revision: 2,
        updatedAt: DateTime.utc(2026, 3, 1, 10),
      );

      final json = profile.toJson();
      expect(json['accessRole'], 'congregationStaff');
      expect(json['congregationId'], 'cong-1');
      expect(json['active'], true);
      expect(json['revision'], 2);

      final decoded = AccessProfile.fromJson(json);
      expect(decoded.accessRole, AccessRole.congregationStaff);
      expect(decoded.congregationId, 'cong-1');
      expect(decoded.active, true);
      expect(decoded.revision, 2);
      expect(decoded.updatedAt, DateTime.utc(2026, 3, 1, 10));
    });

    test('rejects an unknown access role as a controlled data error', () {
      expect(
        () => AccessRole.fromWire('administrator'),
        throwsA(isA<DataFormatException>()),
      );
    });
  });

  group('Student', () {
    Student buildStudent({CalendarDate? birthDate}) => Student(
      metadata: meta(id: 'st-1'),
      name: 'João',
      normalizedName: 'joao',
      congregationId: 'cong-1',
      phoneE164: null,
      birthDate: birthDate,
      address: const Address(
        street: 'Rua Um',
        district: null,
        city: 'Recife',
        postalCode: '50000000',
        stateCode: 'PE',
      ),
      education: null,
      maritalStatus: null,
      newConvert: null,
      waterBaptized: null,
      wantsBaptism: null,
      archived: false,
    );

    test('keeps unanswered religious and optional fields null', () {
      final json = buildStudent().toJson();
      expect(json.containsKey('newConvert'), isTrue);
      expect(json['newConvert'], isNull);
      expect(json.containsKey('waterBaptized'), isTrue);
      expect(json['waterBaptized'], isNull);
      expect(json.containsKey('wantsBaptism'), isTrue);
      expect(json['wantsBaptism'], isNull);
      expect(json['education'], isNull);
      expect(json['maritalStatus'], isNull);

      final decoded = Student.fromJson(json);
      expect(decoded.newConvert, isNull);
      expect(decoded.waterBaptized, isNull);
      expect(decoded.wantsBaptism, isNull);
      expect(decoded.address, isNotNull);
      expect(decoded.address!.city, 'Recife');
    });

    test('preserves null versus false for religious answers', () {
      final student = Student(
        metadata: meta(),
        name: 'Ana',
        normalizedName: 'ana',
        congregationId: 'cong-1',
        phoneE164: null,
        birthDate: null,
        address: null,
        education: null,
        maritalStatus: null,
        newConvert: false,
        waterBaptized: false,
        wantsBaptism: null,
        archived: false,
      );
      final decoded = Student.fromJson(student.toJson());
      expect(decoded.newConvert, isFalse);
      expect(decoded.waterBaptized, isFalse);
      expect(decoded.wantsBaptism, isNull);
    });

    test('does not shift a leap-day birth date through JSON', () {
      final student = buildStudent(birthDate: CalendarDate(2024, 2, 29));
      final json = student.toJson();
      expect(json['birthDate'], '2024-02-29');
      expect(Student.fromJson(json).birthDate, CalendarDate(2024, 2, 29));
    });

    test('rejects stored baptized-and-wants-baptism contradiction', () {
      final json = buildStudent().toJson();
      json['waterBaptized'] = true;
      json['wantsBaptism'] = true;
      expect(() => Student.fromJson(json), throwsA(isA<DataFormatException>()));
    });
  });

  group('ClassGroup', () {
    test('round-trips dates, status and a nullable teacher', () {
      final group = ClassGroup(
        metadata: meta(id: 'cl-1'),
        congregationId: 'cong-1',
        name: 'Turma A',
        normalizedName: 'turma a',
        teacherContactId: 'ct-1',
        startDate: CalendarDate(2026, 2, 1),
        endDate: null,
        status: ClassStatus.active,
      );

      final json = group.toJson();
      expect(json['startDate'], '2026-02-01');
      expect(json['endDate'], isNull);
      expect(json['status'], 'active');
      expect(json['teacherContactId'], 'ct-1');

      final decoded = ClassGroup.fromJson(json);
      expect(decoded.startDate, CalendarDate(2026, 2, 1));
      expect(decoded.endDate, isNull);
      expect(decoded.status, ClassStatus.active);
    });

    test('rejects an unknown class status', () {
      final json = ClassGroup(
        metadata: meta(),
        congregationId: 'cong-1',
        name: 'Turma A',
        normalizedName: 'turma a',
        teacherContactId: null,
        startDate: CalendarDate(2026, 2, 1),
        endDate: null,
        status: ClassStatus.active,
      ).toJson();
      json['status'] = 'paused';
      expect(
        () => ClassGroup.fromJson(json),
        throwsA(isA<DataFormatException>()),
      );
    });
  });

  group('Enrollment', () {
    test('round-trips the enrollment interval and status', () {
      final enrollment = Enrollment(
        metadata: meta(id: 'en-1'),
        studentId: 'st-1',
        classId: 'cl-1',
        congregationId: 'cong-1',
        startDate: CalendarDate(2026, 2, 1),
        endDate: CalendarDate(2026, 6, 30),
        status: EnrollmentStatus.withdrawn,
      );

      final json = enrollment.toJson();
      expect(json['studentId'], 'st-1');
      expect(json['classId'], 'cl-1');
      expect(json['startDate'], '2026-02-01');
      expect(json['endDate'], '2026-06-30');
      expect(json['status'], 'withdrawn');

      final decoded = Enrollment.fromJson(json);
      expect(decoded.studentId, 'st-1');
      expect(decoded.endDate, CalendarDate(2026, 6, 30));
      expect(decoded.status, EnrollmentStatus.withdrawn);
    });
  });

  group('Session', () {
    test('round-trips date, topic, status and roster flag', () {
      final session = Session(
        metadata: meta(id: 'se-1'),
        classId: 'cl-1',
        congregationId: 'cong-1',
        date: CalendarDate(2026, 3, 1),
        topic: 'Batismo',
        status: SessionStatus.finalized,
        rosterFrozen: true,
      );

      final json = session.toJson();
      expect(json['date'], '2026-03-01');
      expect(json['topic'], 'Batismo');
      expect(json['status'], 'finalized');
      expect(json['rosterFrozen'], true);

      final decoded = Session.fromJson(json);
      expect(decoded.date, CalendarDate(2026, 3, 1));
      expect(decoded.topic, 'Batismo');
      expect(decoded.status, SessionStatus.finalized);
      expect(decoded.rosterFrozen, true);
    });

    test('keeps an absent topic explicit as null', () {
      final json = Session(
        metadata: meta(),
        classId: 'cl-1',
        congregationId: 'cong-1',
        date: CalendarDate(2026, 3, 1),
        topic: null,
        status: SessionStatus.open,
        rosterFrozen: false,
      ).toJson();
      expect(json.containsKey('topic'), isTrue);
      expect(json['topic'], isNull);
    });

    test('rejects an unknown session status', () {
      final json = Session(
        metadata: meta(),
        classId: 'cl-1',
        congregationId: 'cong-1',
        date: CalendarDate(2026, 3, 1),
        topic: null,
        status: SessionStatus.open,
        rosterFrozen: false,
      ).toJson();
      json['status'] = 'draft';
      expect(() => Session.fromJson(json), throwsA(isA<DataFormatException>()));
    });
  });

  group('Attendance', () {
    test('round-trips the enrollment key and status', () {
      final attendance = Attendance(
        metadata: meta(id: 'en-1'),
        studentId: 'st-1',
        enrollmentId: 'en-1',
        status: AttendanceStatus.excused,
      );

      final json = attendance.toJson();
      expect(json['studentId'], 'st-1');
      expect(json['enrollmentId'], 'en-1');
      expect(json['status'], 'excused');

      final decoded = Attendance.fromJson(json);
      expect(decoded.studentId, 'st-1');
      expect(decoded.enrollmentId, 'en-1');
      expect(decoded.status, AttendanceStatus.excused);
    });

    test('rejects an unknown attendance status', () {
      final json = Attendance(
        metadata: meta(),
        studentId: 'st-1',
        enrollmentId: 'en-1',
        status: AttendanceStatus.unmarked,
      ).toJson();
      json['status'] = 'pending';
      expect(
        () => Attendance.fromJson(json),
        throwsA(isA<DataFormatException>()),
      );
    });
  });
}
