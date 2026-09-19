/// The composed S10 router, shell and scope guard.
///
/// All route builders resolve their scope from the validated session and the
/// `congregacao` URL parameter before a repository is touched, so a forged
/// deep link is refused rather than rendered. URL filters are read on entry
/// and written back on change, and an unknown path renders the accessible
/// not-found page.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/access.dart';
import '../domain/class_group.dart';
import '../domain/common.dart';
import '../domain/contact.dart';
import '../domain/ports.dart';
import '../domain/session.dart';
import '../domain/student.dart';
import '../features/attendance/attendance_controller.dart';
import '../features/attendance/attendance_page.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/password_reset_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/classes/academic_repository.dart';
import '../features/classes/class_controller.dart';
import '../features/classes/class_detail_page.dart';
import '../features/classes/class_form.dart';
import '../features/classes/classes_page.dart';
import '../features/congregations/congregations_page.dart';
import '../features/overview/overview_controller.dart';
import '../features/overview/overview_page.dart';
import '../features/overview/overview_repository.dart';
import '../features/students/student_detail_page.dart';
import '../features/students/student_form_page.dart';
import '../features/students/student_repository.dart';
import '../features/students/students_page.dart';
import '../features/team/contact_page.dart';
import '../features/team/team_page.dart';
import '../features/team/team_repository.dart';
import '../ui/responsive_scaffold.dart';
import 'dependencies.dart';
import 'navigation.dart';
import 'not_found_page.dart';

GoRouter buildRouter(AppDependencies dependencies) {
  return GoRouter(
    initialLocation: AppRoutes.signIn,
    refreshListenable: dependencies.authController,
    redirect: (BuildContext context, GoRouterState state) =>
        _redirect(dependencies, state),
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const NotFoundPage(),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.signIn,
        builder: (BuildContext context, GoRouterState state) => SignInPage(
          controller: dependencies.authController,
          returnTo: state.uri.queryParameters['from'],
          onAuthenticated: (String destination) =>
              dependencies.router.go(destination),
          onForgotPassword: () =>
              dependencies.router.go(AppRoutes.passwordReset),
        ),
      ),
      GoRoute(
        path: AppRoutes.passwordReset,
        builder: (BuildContext context, GoRouterState state) =>
            PasswordResetPage(controller: dependencies.authController),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AppShell(
              dependencies: dependencies,
              location: state.matchedLocation,
              child: child,
            ),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.overview,
            builder: (BuildContext context, GoRouterState state) =>
                _overviewRoute(dependencies, state),
          ),
          GoRoute(
            path: AppRoutes.team,
            builder: (BuildContext context, GoRouterState state) =>
                _teamRoute(dependencies, state),
            routes: <RouteBase>[
              GoRoute(
                path: ':contactId',
                builder: (BuildContext context, GoRouterState state) =>
                    _contactRoute(dependencies, state),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.students,
            builder: (BuildContext context, GoRouterState state) =>
                _studentsRoute(dependencies, state),
            routes: <RouteBase>[
              GoRoute(
                path: 'novo',
                builder: (BuildContext context, GoRouterState state) =>
                    _newStudentRoute(dependencies, state),
              ),
              GoRoute(
                path: ':studentId',
                builder: (BuildContext context, GoRouterState state) =>
                    _studentDetailRoute(dependencies, state),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'editar',
                    builder: (BuildContext context, GoRouterState state) =>
                        _studentEditRoute(dependencies, state),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.classes,
            builder: (BuildContext context, GoRouterState state) =>
                _classesRoute(dependencies, state),
            routes: <RouteBase>[
              GoRoute(
                path: 'nova',
                builder: (BuildContext context, GoRouterState state) =>
                    _newClassRoute(dependencies, state),
              ),
              GoRoute(
                path: ':classId',
                builder: (BuildContext context, GoRouterState state) =>
                    _classDetailRoute(dependencies, state),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'chamadas/:sessionId',
                    builder: (BuildContext context, GoRouterState state) =>
                        _attendanceRoute(dependencies, state),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.congregations,
            builder: (BuildContext context, GoRouterState state) =>
                _congregationsRoute(dependencies, state),
          ),
        ],
      ),
    ],
  );
}

String? _redirect(AppDependencies dependencies, GoRouterState state) {
  final AuthState auth = dependencies.authController.state;
  final String location = state.matchedLocation;
  final bool onAuthRoute =
      location == AppRoutes.signIn || location == AppRoutes.passwordReset;

  // Session loading must not bounce the destination: the router waits.
  if (auth.status == AuthStatus.loading ||
      auth.status == AuthStatus.accessDenied) {
    return null;
  }
  if (!auth.isAuthorized) {
    if (onAuthRoute) {
      return null;
    }
    final String from = Uri(
      path: location,
      queryParameters: state.uri.queryParameters,
    ).toString();
    return Uri(
      path: AppRoutes.signIn,
      queryParameters: <String, String>{'from': from},
    ).toString();
  }
  if (onAuthRoute) {
    return sanitizeReturnTo(state.uri.queryParameters['from']) ??
        AppRoutes.overview;
  }
  return null;
}

/// The authenticated shell: responsive navigation around the page.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.dependencies,
    required this.location,
    required this.child,
  });

  final AppDependencies dependencies;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AuthState auth = dependencies.authController.state;
    final AuthSession? session = auth.session;
    if (session == null || !auth.isAuthorized) {
      return const _SessionLoadingPage();
    }
    final List<NavEntry> entries = navEntriesFor(session.profile.accessRole);
    return ResponsiveScaffold(
      title: 'Discipulado IEADPE',
      destinations: entries
          .map((NavEntry entry) => entry.toDestination())
          .toList(growable: false),
      selectedIndex: selectedNavIndex(entries, location),
      onDestinationSelected: (int index) async {
        if (dependencies.navigationGuard.isDirty &&
            !await dependencies.navigationGuard.handleInAppNavigation()) {
          return;
        }
        dependencies.router.go(entries[index].path);
      },
      body: child,
    );
  }
}

class _SessionLoadingPage extends StatelessWidget {
  const _SessionLoadingPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// The resolved scope for a scoped route.
class _ScopedRoute {
  const _ScopedRoute({this.congregationId, this.forbidden = false});

  final String? congregationId;
  final bool forbidden;
}

_ScopedRoute _resolveScope(AuthSession session, GoRouterState state) {
  final String? requested = _nonEmpty(state.uri.queryParameters['congregacao']);
  if (session.profile.accessRole == AccessRole.supervisor) {
    return _ScopedRoute(
      congregationId: requested ?? session.profile.congregationId,
    );
  }
  final String? bound = session.profile.congregationId;
  if (bound == null) {
    return const _ScopedRoute(forbidden: true);
  }
  if (requested != null && requested != bound) {
    return const _ScopedRoute(forbidden: true);
  }
  return _ScopedRoute(congregationId: bound);
}

String? _nonEmpty(String? value) {
  final String? trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

String _pathWithScope(
  String path, {
  String? congregationId,
  Map<String, String> extra = const <String, String>{},
}) {
  final Map<String, String> params = <String, String>{...extra};
  if (congregationId != null && congregationId.isNotEmpty) {
    params['congregacao'] = congregationId;
  }
  return Uri(
    path: path,
    queryParameters: params.isEmpty ? null : params,
  ).toString();
}

bool _sameFilters(Map<String, String> a, Map<String, String> b) =>
    mapEquals(a, b);

// --- Route builders -------------------------------------------------------

Widget _overviewRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden) {
    return const ForbiddenPage();
  }
  final SessionControllers controllers = dependencies
      .requireSessionControllers();
  final OverviewQuery desired = OverviewQuery.fromQueryParameters(
    state.uri.queryParameters,
  );
  if (dependencies.authController.state.session!.profile.accessRole ==
          AccessRole.supervisor &&
      controllers.overview.congregationId != scope.congregationId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controllers.overview.setCongregation(scope.congregationId);
    });
  }
  if (controllers.overview.pendingVisible != desired.pending) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controllers.overview.setPendingVisible(desired.pending);
    });
  }
  return _UrlSync(
    router: dependencies.router,
    controller: controllers.overview,
    path: AppRoutes.overview,
    current: state.uri.queryParameters,
    read: controllers.overview.toQueryParameters,
    child: OverviewPage(
      controller: controllers.overview,
      onOpenStudents: (String? congregationId) => dependencies.router.go(
        _pathWithScope(AppRoutes.students, congregationId: congregationId),
      ),
      onOpenClasses: (ClassesLinkTarget target) => dependencies.router.go(
        _pathWithScope(
          AppRoutes.classes,
          congregationId: target.congregationId,
          extra: <String, String>{
            if (target.status != null) 'situacao': target.status!.wire,
          },
        ),
      ),
      onOpenSession: (PendingSessionEntry entry) => dependencies.router.go(
        _pathWithScope(
          AppRoutes.attendance(entry.classId, entry.id),
          congregationId: entry.congregationId,
        ),
      ),
    ),
  );
}

Widget _teamRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden) {
    return const ForbiddenPage();
  }
  final SessionControllers controllers = dependencies
      .requireSessionControllers();
  final TeamQuery desired = _parseTeamQuery(state, scope);
  final Map<String, String> desiredParams = desired.toQueryParameters();
  if (!_sameFilters(
    controllers.team.query.toQueryParameters(),
    desiredParams,
  )) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controllers.team.applyQuery(desired);
    });
  }
  return _UrlSync(
    router: dependencies.router,
    controller: controllers.team,
    path: AppRoutes.team,
    current: state.uri.queryParameters,
    read: () => controllers.team.query.toQueryParameters(),
    child: TeamPage(
      controller: controllers.team,
      onOpenContact: (DirectoryEntry entry) => dependencies.router.go(
        _pathWithScope(
          AppRoutes.contact(entry.id),
          congregationId: entry.congregationId ?? scope.congregationId,
          extra: <String, String>{'escopo': entry.scope.wire},
        ),
      ),
    ),
  );
}

Widget _contactRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden) {
    return const ForbiddenPage();
  }
  final String contactId = state.pathParameters['contactId'] ?? '';
  if (contactId.isEmpty) {
    return const NotFoundPage();
  }
  ContactScope? contactScope;
  final String? rawScope = _nonEmpty(state.uri.queryParameters['escopo']);
  if (rawScope != null) {
    try {
      contactScope = ContactScope.fromWire(rawScope);
    } on DataFormatException {
      return const NotFoundPage();
    }
  }
  return ContactPage(
    repository: dependencies.teamRepository,
    profile: session.profile,
    contactId: contactId,
    catalog: dependencies.congregationRepository,
    scope: contactScope,
    congregationId: scope.congregationId,
    onDone: () => dependencies.router.go(
      _pathWithScope(AppRoutes.team, congregationId: scope.congregationId),
    ),
  );
}

Widget _studentsRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden) {
    return const ForbiddenPage();
  }
  final SessionControllers controllers = dependencies
      .requireSessionControllers();
  final StudentQuery? desired = _parseStudentQuery(state, scope);
  if (desired == null) {
    return const NotFoundPage();
  }
  if (!_sameFilters(
    controllers.students.query.toQueryParameters(),
    desired.toQueryParameters(),
  )) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controllers.students.applyQuery(desired);
    });
  }
  return _UrlSync(
    router: dependencies.router,
    controller: controllers.students,
    path: AppRoutes.students,
    current: state.uri.queryParameters,
    read: () => controllers.students.query.toQueryParameters(),
    child: StudentsPage(
      controller: controllers.students,
      onOpenStudent: (StudentListEntry entry) => dependencies.router.go(
        _pathWithScope(
          AppRoutes.student(entry.id),
          congregationId: entry.congregationId,
        ),
      ),
      onCreate: () => dependencies.router.go(
        _pathWithScope(
          AppRoutes.newStudent,
          congregationId: scope.congregationId,
        ),
      ),
    ),
  );
}

Widget _newStudentRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden) {
    return const ForbiddenPage();
  }
  final String? congregationId = scope.congregationId;
  if (congregationId == null) {
    return const ForbiddenPage(
      message: 'Selecione uma congregação antes de criar um aluno.',
    );
  }
  return StudentFormPage(
    repository: dependencies.studentRepository,
    config: StudentFormConfig(congregationId: congregationId),
    onSaved: (StudentMutationResult result) => dependencies.router.go(
      _pathWithScope(
        AppRoutes.student(result.id),
        congregationId: congregationId,
      ),
    ),
    onCancel: () => dependencies.router.go(
      _pathWithScope(AppRoutes.students, congregationId: congregationId),
    ),
  );
}

Widget _studentDetailRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden || scope.congregationId == null) {
    return const ForbiddenPage();
  }
  final String studentId = state.pathParameters['studentId'] ?? '';
  if (studentId.isEmpty) {
    return const NotFoundPage();
  }
  return StudentDetailPage(
    repository: dependencies.studentRepository,
    studentId: studentId,
    congregationId: scope.congregationId!,
    onDone: () => dependencies.router.go(
      _pathWithScope(AppRoutes.students, congregationId: scope.congregationId),
    ),
  );
}

Widget _studentEditRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden || scope.congregationId == null) {
    return const ForbiddenPage();
  }
  final String studentId = state.pathParameters['studentId'] ?? '';
  if (studentId.isEmpty) {
    return const NotFoundPage();
  }
  return _StudentEditLoader(
    dependencies: dependencies,
    studentId: studentId,
    congregationId: scope.congregationId!,
  );
}

Widget _classesRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden) {
    return const ForbiddenPage();
  }
  final SessionControllers controllers = dependencies
      .requireSessionControllers();
  final ClassQuery? desired = _parseClassQuery(state, scope);
  if (desired == null) {
    return const NotFoundPage();
  }
  if (!_sameFilters(
    controllers.classes.query.toQueryParameters(),
    desired.toQueryParameters(),
  )) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controllers.classes.applyQuery(desired);
    });
  }
  final ClassController controller = controllers.classes;
  return _UrlSync(
    router: dependencies.router,
    controller: controller,
    path: AppRoutes.classes,
    current: state.uri.queryParameters,
    read: () => controller.query.toQueryParameters(),
    child: ClassesPage(
      controller: controller,
      onOpenClass: (ClassListEntry entry) => dependencies.router.go(
        _pathWithScope(
          AppRoutes.classDetail(entry.id),
          congregationId: entry.congregationId,
        ),
      ),
      onCreate: () => dependencies.router.go(
        _pathWithScope(
          AppRoutes.newClass,
          congregationId: scope.congregationId,
        ),
      ),
    ),
  );
}

Widget _newClassRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden) {
    return const ForbiddenPage();
  }
  final String? congregationId = scope.congregationId;
  if (congregationId == null) {
    return const ForbiddenPage(
      message: 'Selecione uma congregação antes de criar uma turma.',
    );
  }
  return ClassForm(
    repository: dependencies.academicRepository,
    config: ClassFormConfig(congregationId: congregationId),
    onSaved: (AcademicMutationResult result) => dependencies.router.go(
      _pathWithScope(
        AppRoutes.classDetail(result.id),
        congregationId: congregationId,
      ),
    ),
    onCancel: () => dependencies.router.go(
      _pathWithScope(AppRoutes.classes, congregationId: congregationId),
    ),
  );
}

Widget _classDetailRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden || scope.congregationId == null) {
    return const ForbiddenPage();
  }
  final String classId = state.pathParameters['classId'] ?? '';
  if (classId.isEmpty) {
    return const NotFoundPage();
  }
  final String congregationId = scope.congregationId!;
  return ClassDetailPage(
    repository: dependencies.academicRepository,
    classId: classId,
    congregationId: congregationId,
    onOpenSession: (ClassGroup classGroup, Session session) =>
        dependencies.router.go(
          _pathWithScope(
            AppRoutes.attendance(classGroup.id, session.id),
            congregationId: congregationId,
          ),
        ),
    onDone: () => dependencies.router.go(
      _pathWithScope(AppRoutes.classes, congregationId: congregationId),
    ),
  );
}

Widget _attendanceRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  final _ScopedRoute scope = _resolveScope(session, state);
  if (scope.forbidden || scope.congregationId == null) {
    return const ForbiddenPage();
  }
  final String classId = state.pathParameters['classId'] ?? '';
  final String sessionId = state.pathParameters['sessionId'] ?? '';
  if (classId.isEmpty || sessionId.isEmpty) {
    return const NotFoundPage();
  }
  return _AttendanceRoute(
    dependencies: dependencies,
    congregationId: scope.congregationId!,
    classId: classId,
    sessionId: sessionId,
  );
}

Widget _congregationsRoute(AppDependencies dependencies, GoRouterState state) {
  if (!dependencies.authController.state.isAuthorized) {
    return const _SessionLoadingPage();
  }
  final AuthSession session = dependencies.requireSession();
  if (session.profile.accessRole != AccessRole.supervisor) {
    return const ForbiddenPage();
  }
  final SessionControllers controllers = dependencies
      .requireSessionControllers();
  return CongregationsPage(controller: controllers.congregations);
}

// --- Parsing helpers ------------------------------------------------------

TeamQuery _parseTeamQuery(GoRouterState state, _ScopedRoute scope) {
  final TeamQuery parsed = TeamQuery.fromQueryParameters(
    state.uri.queryParameters,
  );
  return parsed.copyWith(
    congregationId: scope.congregationId,
    clearCongregation: scope.congregationId == null,
  );
}

StudentQuery? _parseStudentQuery(GoRouterState state, _ScopedRoute scope) {
  try {
    return StudentQuery.fromQueryParameters(state.uri.queryParameters).copyWith(
      congregationId: scope.congregationId,
      clearCongregation: scope.congregationId == null,
    );
  } on DataFormatException {
    return null;
  }
}

ClassQuery? _parseClassQuery(GoRouterState state, _ScopedRoute scope) {
  try {
    return ClassQuery.fromQueryParameters(state.uri.queryParameters).copyWith(
      congregationId: scope.congregationId,
      clearCongregation: scope.congregationId == null,
    );
  } on DataFormatException {
    return null;
  }
}

// --- Stateful route wrappers ---------------------------------------------

/// Writes the controller's URL-addressable state back into the route.
class _UrlSync extends StatefulWidget {
  const _UrlSync({
    required this.router,
    required this.controller,
    required this.path,
    required this.current,
    required this.read,
    required this.child,
  });

  final GoRouter router;
  final Listenable controller;
  final String path;
  final Map<String, String> current;
  final Map<String, String> Function() read;
  final Widget child;

  @override
  State<_UrlSync> createState() => _UrlSyncState();
}

class _UrlSyncState extends State<_UrlSync> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(_UrlSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    final Map<String, String> next = widget.read();
    if (_sameFilters(next, widget.current)) {
      return;
    }
    final Uri uri = Uri(
      path: widget.path,
      queryParameters: next.isEmpty ? null : next,
    );
    widget.router.replace(uri.toString());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Deep-linkable attendance editor: one controller per route entry.
class _AttendanceRoute extends StatefulWidget {
  const _AttendanceRoute({
    required this.dependencies,
    required this.congregationId,
    required this.classId,
    required this.sessionId,
  });

  final AppDependencies dependencies;
  final String congregationId;
  final String classId;
  final String sessionId;

  @override
  State<_AttendanceRoute> createState() => _AttendanceRouteState();
}

class _AttendanceRouteState extends State<_AttendanceRoute> {
  late final AttendanceController _controller = AttendanceController(
    repository: widget.dependencies.academicRepository,
    congregationId: widget.congregationId,
    classId: widget.classId,
    sessionId: widget.sessionId,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AttendancePage(
    controller: _controller,
    onCanceled: () => widget.dependencies.router.go(
      _pathWithScope(
        AppRoutes.classDetail(widget.classId),
        congregationId: widget.congregationId,
      ),
    ),
  );
}

/// Loads the private student before rendering the edit form at `/editar`.
class _StudentEditLoader extends StatefulWidget {
  const _StudentEditLoader({
    required this.dependencies,
    required this.studentId,
    required this.congregationId,
  });

  final AppDependencies dependencies;
  final String studentId;
  final String congregationId;

  @override
  State<_StudentEditLoader> createState() => _StudentEditLoaderState();
}

class _StudentEditLoaderState extends State<_StudentEditLoader> {
  Student? _student;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Student? student = await widget.dependencies.studentRepository
          .getStudent(
            id: widget.studentId,
            congregationId: widget.congregationId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _student = student;
        _notFound = student == null;
        _loading = false;
      });
    } on AppFailure {
      if (!mounted) {
        return;
      }
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SessionLoadingPage();
    }
    final Student? student = _student;
    if (_notFound || student == null) {
      return const NotFoundPage();
    }
    return StudentFormPage(
      repository: widget.dependencies.studentRepository,
      config: StudentFormConfig(
        congregationId: widget.congregationId,
        studentId: student.id,
        expectedRevision: student.revision,
        initial: student,
      ),
      onSaved: (StudentMutationResult result) => widget.dependencies.router.go(
        _pathWithScope(
          AppRoutes.student(result.id),
          congregationId: widget.congregationId,
        ),
      ),
      onCancel: () => widget.dependencies.router.go(
        _pathWithScope(
          AppRoutes.student(student.id),
          congregationId: widget.congregationId,
        ),
      ),
    );
  }
}
