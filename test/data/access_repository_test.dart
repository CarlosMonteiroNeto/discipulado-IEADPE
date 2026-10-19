import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/access_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_codec.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/domain/models.dart';

import 'repositories_test.dart' as fixture;

const _scopeId = '22222222-2222-4222-8222-222222222222';
const _operationId = '33333333-3333-4333-8333-333333333333';
String _id(int value) =>
    '11111111-1111-4111-8111-${value.toString().padLeft(12, '0')}';

void main() {
  test('directory projection preserves revision, nullable email, and global link ID', () {
    final page = decodeDirectoryPage({
      'items': [
        {
          'id': _id(1),
          'name': 'Teacher One',
          'normalized_name': 'teacher one',
          'scope': 'congregation',
          'congregation_id': _scopeId,
          'role_code': 'teacher',
          'phone_e164': null,
          'birth_date': null,
          'email': null,
          'archived_at': null,
          'revision': 3,
          'user_access_id': null,
        },
      ],
      'next_cursor': null,
    });
    final dynamic entry = page.items.single;
    expect(entry.revision, 3);
    expect(entry.email, isNull);
    expect(entry.userAccessId, isNull);
  });

  test(
    'contact detail keeps access authority separate from contact role',
    () async {
      final gateway = await fixture.fixture((request) async {
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_get_contact');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'request': {
            'scope': 'congregation',
            'congregation_id': _scopeId,
            'contact_id': _id(1),
          },
        });
        await fixture.respond(request, {
          'contact': {
            'id': _id(1),
            'name': 'Teacher One',
            'normalized_name': 'teacher one',
            'scope': 'congregation',
            'congregation_id': _scopeId,
            'role_code': 'teacher',
            'phone_e164': null,
            'birth_date': null,
            'email': 'teacher@example.test',
            'archived_at': null,
            'revision': 2,
            'user_access_id': _id(2),
            'created_at': '2026-10-19T10:00:00Z',
            'updated_at': '2026-10-19T10:01:00Z',
            'updated_by': _id(3),
          },
          'access': {
            'id': _id(2),
            'user_email': 'teacher@example.test',
            'role': 'Membro da direção da campanha',
            'congregation_id': _scopeId,
            'user_id': _id(4),
          },
        });
      });
      final repository = MinistryRepository(gateway);
      final dynamic detail = await (repository as dynamic).getContact(
        scope: ContactScope.congregation,
        congregationId: _scopeId,
        contactId: _id(1),
      );

      expect(detail.contact.roleCode, RoleCode.teacher);
      expect(detail.contact.email, 'teacher@example.test');
      expect(detail.contact.userAccessId, _id(2));
      expect(detail.access.role, AccessRole.direction);
      expect(detail.access.id, _id(2));
    },
  );

  test(
    'contact and access grant are submitted in one revisioned command',
    () async {
      final gateway = await fixture.fixture((request) async {
        expect(
          request.uri.path,
          '/rest/v1/rpc/ieadpe_ministry_save_contact_with_access',
        );
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'operation_id': _operationId,
          'payload': {
            'id': _id(1),
            'expected_revision': 4,
            'scope': 'congregation',
            'congregation_id': _scopeId,
            'name': 'Teacher One',
            'role_code': 'teacher',
            'phone_e164': null,
            'birth_date': null,
            'email': 'teacher@example.test',
            'access': {
              'id': _id(2),
              'user_email': 'teacher@example.test',
              'role': AccessRole.direction.wireValue,
              'congregation_id': _scopeId,
            },
          },
        });
        await fixture.respond(request, {
          'id': _id(1),
          'revision': 5,
          'access_id': _id(2),
        });
      });
      final repository = MinistryRepository(gateway);
      final dynamic result = await (repository as dynamic)
          .saveContactWithAccess(
            operationId: _operationId,
            id: _id(1),
            expectedRevision: 4,
            scope: ContactScope.congregation,
            congregationId: _scopeId,
            name: 'Teacher One',
            roleCode: RoleCode.teacher,
            phoneE164: null,
            birthDate: null,
            email: 'teacher@example.test',
            accessId: _id(2),
            accessRole: AccessRole.direction,
            accessCongregationId: _scopeId,
          );
      expect(result.id, _id(1));
      expect(result.revision, 5);
      expect(result.accessId, _id(2));
    },
  );

  test(
    'access repository exposes assignments with a distinct access role type',
    () async {
      final gateway = await fixture.fixture((request) async {
        expect(request.uri.path, '/rest/v1/user_access');
        await fixture.respond(request, [
          {
            'id': _id(2),
            'user_email': 'teacher@example.test',
            'role': AccessRole.direction.wireValue,
            'congregation_id': _scopeId,
            'user_id': _id(4),
          },
        ]);
      });
      final dynamic page = await (AccessRepository(gateway) as dynamic)
          .listAssignments();
      expect(page.items.single.runtimeType.toString(), 'TeamAccessAssignment');
      expect(page.items.single.role, AccessRole.direction);
      expect(page.items.single.boundUserId, _id(4));
    },
  );
}
