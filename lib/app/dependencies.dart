/// The composed dependency graph (S11).
///
/// Real repositories are constructed over the injected [BackendGateway] and
/// [AuthRepository]; session-scoped controllers are created only for an
/// authorized [AuthSession] and are attached to [AuthController] so a sign-out
/// or scope change disposes the old data before the next frame renders.
library;

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../data/firebase_configuration.dart';
import '../domain/access.dart';
import '../domain/ports.dart';
import '../features/auth/auth_controller.dart';
import '../features/classes/academic_repository.dart';
import '../features/classes/class_controller.dart';
import '../features/congregations/congregation_controller.dart';
import '../features/congregations/congregation_repository.dart';
import '../features/overview/overview_controller.dart';
import '../features/overview/overview_repository.dart';
import '../features/students/student_controller.dart';
import '../features/students/student_repository.dart';
import '../features/team/team_controller.dart';
import '../features/team/team_repository.dart';
import '../ui/dirty_form_guard.dart';
import 'router.dart';

/// Feature controllers bound to one authorized session.
class SessionControllers {
  SessionControllers._({
    required this.authController,
    required this.profile,
    required this.team,
    required this.students,
    required this.classes,
    required this.overview,
    required this.congregations,
  }) {
    _all = <SessionScoped>[team, students, classes, overview, congregations];
  }

  factory SessionControllers.forSession(
    AppDependencies dependencies,
    AuthSession session,
  ) {
    final AccessProfile profile = session.profile;
    return SessionControllers._(
      authController: dependencies.authController,
      profile: profile,
      team: TeamController(
        repository: dependencies.teamRepository,
        profile: profile,
        catalog: dependencies.congregationRepository,
      ),
      students: StudentController(
        repository: dependencies.studentRepository,
        profile: profile,
        catalog: dependencies.congregationRepository,
      ),
      classes: ClassController(
        repository: dependencies.academicRepository,
        profile: profile,
        catalog: dependencies.congregationRepository,
      ),
      overview: OverviewController(
        repository: dependencies.overviewRepository,
        profile: profile,
        catalog: dependencies.congregationRepository,
      ),
      congregations: CongregationController(
        repository: dependencies.congregationRepository,
        profile: profile,
      ),
    );
  }

  final AuthController authController;
  final AccessProfile profile;
  final TeamController team;
  final StudentController students;
  final ClassController classes;
  final OverviewController overview;
  final CongregationController congregations;
  late final List<SessionScoped> _all;

  /// Whether these controllers still belong to [session]'s identity and scope.
  bool matches(AuthSession session) =>
      profile.accessRole == session.profile.accessRole &&
      profile.congregationId == session.profile.congregationId;

  void attachTo() {
    for (final SessionScoped scoped in _all) {
      authController.attach(scoped);
    }
  }

  void dispose() {
    for (final SessionScoped scoped in _all) {
      authController.detach(scoped);
      if (scoped is ChangeNotifier) {
        (scoped as ChangeNotifier).dispose();
      }
    }
  }
}

class AppDependencies {
  AppDependencies._({
    required this.authRepository,
    required this.gateway,
    required this.configuration,
    required this.authController,
    required this.teamRepository,
    required this.studentRepository,
    required this.academicRepository,
    required this.overviewRepository,
    required this.congregationRepository,
  }) {
    router = buildRouter(this);
  }

  /// Builds the real repository graph over explicitly injected ports. The
  /// transport is the only thing a caller swaps, so no feature ever reaches
  /// Firebase directly.
  factory AppDependencies.fromPorts({
    required AuthRepository authRepository,
    required BackendGateway gateway,
    FirebaseConfiguration? configuration,
  }) {
    return AppDependencies._(
      authRepository: authRepository,
      gateway: gateway,
      configuration: configuration,
      authController: AuthController(repository: authRepository),
      teamRepository: TeamRepository(gateway: gateway),
      studentRepository: StudentRepository(gateway: gateway),
      academicRepository: AcademicRepository(gateway: gateway),
      overviewRepository: OverviewRepository(gateway: gateway),
      congregationRepository: CongregationRepository(gateway: gateway),
    );
  }

  final AuthRepository authRepository;
  final BackendGateway gateway;
  final FirebaseConfiguration? configuration;
  final AuthController authController;
  final TeamRepository teamRepository;
  final StudentRepository studentRepository;
  final AcademicRepository academicRepository;
  final OverviewRepository overviewRepository;
  final CongregationRepository congregationRepository;

  late final GoRouter router;

  /// App-level hook for the in-app navigation protection of dirty forms. Forms
  /// register their guard through [DirtyFormGuard.registerInAppNavigationHook];
  /// the shell consults it before leaving a route.
  final DirtyFormGuard navigationGuard = DirtyFormGuard();

  SessionControllers? _sessionControllers;

  SessionControllers? get sessionControllers => _sessionControllers;

  /// The current authorized session, or a state error when none exists. Route
  /// builders run behind the router guard, so this is only reachable while
  /// authorized.
  AuthSession requireSession() {
    final AuthSession? session = authController.state.session;
    if (session == null || !authController.state.isAuthorized) {
      throw StateError('No authorized session is loaded.');
    }
    return session;
  }

  /// Returns the controllers for the current session, recreating them when the
  /// identity or scope changed so a previous congregation's data is disposed.
  SessionControllers requireSessionControllers() {
    final AuthSession session = requireSession();
    final SessionControllers? current = _sessionControllers;
    if (current == null || !current.matches(session)) {
      current?.dispose();
      final SessionControllers next = SessionControllers.forSession(
        this,
        session,
      )..attachTo();
      _sessionControllers = next;
    }
    return _sessionControllers!;
  }

  void disposeSessionControllers() {
    _sessionControllers?.dispose();
    _sessionControllers = null;
  }
}
