/// S10 route table and the authenticated navigation destinations.
///
/// The composed shell consumes these entries; labels and the supervisor-only
/// destination follow S06/S10. This file owns route strings only: pages come
/// from the feature folders and the shell from `app.dart`.
library;

import 'package:flutter/material.dart';

import '../domain/access.dart';
import '../ui/responsive_scaffold.dart';

abstract final class AppRoutes {
  static const String signIn = '/entrar';
  static const String passwordReset = '/recuperar-senha';
  static const String overview = '/visao-geral';
  static const String team = '/equipe';
  static const String students = '/alunos';
  static const String newStudent = '/alunos/novo';
  static const String classes = '/turmas';
  static const String newClass = '/turmas/nova';
  static const String congregations = '/congregacoes';

  /// Parameter patterns, used for the declared route table.
  static const String contactPattern = '/equipe/:contactId';
  static const String studentPattern = '/alunos/:studentId';
  static const String editStudentPattern = '/alunos/:studentId/editar';
  static const String classPattern = '/turmas/:classId';
  static const String attendancePattern =
      '/turmas/:classId/chamadas/:sessionId';

  static String contact(String contactId) => '/equipe/$contactId';

  static String student(String studentId) => '/alunos/$studentId';

  static String editStudent(String studentId) => '/alunos/$studentId/editar';

  static String classDetail(String classId) => '/turmas/$classId';

  static String attendance(String classId, String sessionId) =>
      '/turmas/$classId/chamadas/$sessionId';

  /// Every S10 route pattern, in declaration order.
  static const List<String> all = <String>[
    signIn,
    passwordReset,
    overview,
    team,
    contactPattern,
    students,
    newStudent,
    studentPattern,
    editStudentPattern,
    classes,
    newClass,
    classPattern,
    attendancePattern,
    congregations,
  ];
}

/// One navigation destination with its route target.
class NavEntry {
  const NavEntry({
    required this.label,
    required this.path,
    required this.icon,
    this.semanticLabel,
  });

  final String label;
  final String path;
  final IconData icon;
  final String? semanticLabel;

  AppNavDestination toDestination() =>
      AppNavDestination(label: label, icon: icon, semanticLabel: semanticLabel);
}

/// Destinations visible to one access role (S04, S06, S10).
List<NavEntry> navEntriesFor(AccessRole role) => <NavEntry>[
  const NavEntry(
    label: 'Visão geral',
    path: AppRoutes.overview,
    icon: Icons.dashboard_outlined,
    semanticLabel: 'Visão geral',
  ),
  const NavEntry(
    label: 'Equipe',
    path: AppRoutes.team,
    icon: Icons.groups_outlined,
    semanticLabel: 'Equipe',
  ),
  const NavEntry(
    label: 'Alunos',
    path: AppRoutes.students,
    icon: Icons.school_outlined,
    semanticLabel: 'Alunos',
  ),
  const NavEntry(
    label: 'Turmas',
    path: AppRoutes.classes,
    icon: Icons.menu_book_outlined,
    semanticLabel: 'Turmas',
  ),
  if (role == AccessRole.supervisor)
    const NavEntry(
      label: 'Congregações',
      path: AppRoutes.congregations,
      icon: Icons.church_outlined,
      semanticLabel: 'Congregações',
    ),
];

/// The destination whose route best matches [location], for the selected
/// navigation index.
int selectedNavIndex(List<NavEntry> entries, String location) {
  int selected = 0;
  int bestLength = -1;
  for (int index = 0; index < entries.length; index++) {
    final String path = entries[index].path;
    final bool matches = location == path || location.startsWith('$path/');
    if (matches && path.length > bestLength) {
      selected = index;
      bestLength = path.length;
    }
  }
  return selected;
}
