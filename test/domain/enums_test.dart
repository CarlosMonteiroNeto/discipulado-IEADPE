import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/class_group.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/enrollment.dart';
import 'package:discipulado_ieadpe/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('access roles match S04', () {
    expect(AccessRole.values.map((role) => role.wire).toSet(), {
      'supervisor',
      'congregationStaff',
    });
  });

  test('contact scopes match S05', () {
    expect(ContactScope.values.map((scope) => scope.wire).toSet(), {
      'congregation',
      'supervision',
    });
  });

  test('the twelve stable role codes carry their S06 labels and scopes', () {
    expect(RoleCode.values, hasLength(12));

    final codes = {for (final code in RoleCode.values) code.wire: code};

    expect(codes.keys.toSet(), {
      'campaignSupervisor',
      'campaignDeputy',
      'discipleshipCoordinator',
      'discipleshipDeputy',
      'coordinationSecretary',
      'coordinationDeputySecretary',
      'congregationAssistant',
      'campaignLeader',
      'campaignDeputyLeader',
      'teacher',
      'discipleshipSecretary',
      'discipleshipDeputySecretary',
    });

    expect(codes['campaignSupervisor']!.label, 'Supervisor das campanhas');
    expect(codes['campaignSupervisor']!.scope, ContactScope.supervision);
    expect(codes['campaignDeputy']!.label, 'Vice-supervisor das campanhas');
    expect(
      codes['discipleshipCoordinator']!.label,
      'Coordenador do discipulado',
    );
    expect(
      codes['discipleshipDeputy']!.label,
      'Vice-coordenador do discipulado',
    );
    expect(codes['coordinationSecretary']!.label, 'Secretária da coordenação');
    expect(
      codes['coordinationDeputySecretary']!.label,
      'Vice-secretária da coordenação',
    );
    expect(codes['congregationAssistant']!.label, 'Assistente de congregação');
    expect(codes['congregationAssistant']!.scope, ContactScope.congregation);
    expect(codes['campaignLeader']!.label, 'Dirigente de campanha');
    expect(codes['campaignDeputyLeader']!.label, 'Vice-dirigente de campanha');
    expect(codes['teacher']!.label, 'Professor(a) do discipulado');
    expect(codes['teacher']!.scope, ContactScope.congregation);
    expect(codes['discipleshipSecretary']!.label, 'Secretária do discipulado');
    expect(
      codes['discipleshipDeputySecretary']!.label,
      'Vice-secretária do discipulado',
    );
  });

  test('class statuses match S05', () {
    expect(ClassStatus.values.map((status) => status.wire).toSet(), {
      'active',
      'completed',
      'archived',
    });
  });

  test('enrollment statuses match S05', () {
    expect(EnrollmentStatus.values.map((status) => status.wire).toSet(), {
      'active',
      'completed',
      'withdrawn',
    });
  });

  test('session statuses match S05', () {
    expect(SessionStatus.values.map((status) => status.wire).toSet(), {
      'open',
      'finalized',
      'canceled',
    });
  });

  test('attendance statuses match S05 without free-text notes', () {
    expect(AttendanceStatus.values.map((status) => status.wire).toSet(), {
      'present',
      'absent',
      'excused',
      'unmarked',
    });
  });
}
