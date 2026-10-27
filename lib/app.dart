import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'configuration.dart';
import 'data/convert_repository.dart';
import 'data/supabase_gateway.dart';
import 'domain/models.dart';
import 'routing/router.dart';
import 'routing/browser_route_history.dart';
import 'features/auth/login_page.dart';
import 'features/admin/admin_page.dart';
import 'features/admin/congregation_repository.dart';
import 'features/backup/backup_panel.dart';
import 'features/backup/backup_repository.dart';
import 'features/converts/congregation_order.dart';
import 'features/converts/converts_page.dart';
import 'features/converts/register_page.dart';
import 'features/intake/public_intake_page.dart';
import 'features/intake/public_intake_repository.dart';
import 'features/intake/pending_review_page.dart';
import 'features/intake/pending_submission_repository.dart';
import 'features/intake/turnstile_challenge.dart';
import 'features/feedback/feedback_dialog.dart';
import 'features/feedback/feedback_manager.dart';
import 'features/feedback/feedback_repository.dart';
import 'features/home/home_page.dart';
import 'features/home/home_repository.dart';
import 'features/photos/photo_repository.dart';
import 'features/reports/conversion_panel.dart';
import 'features/reports/events_panel.dart';
import 'features/reports/reports_repository.dart';
import 'features/weekly/weekly_repository.dart';
import 'platform/file_exporter.dart';
import 'platform/import_progress_store.dart';
import 'widgets/app_shell.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/session_display_name.dart';
import 'features/ministry/data/ministry_browser_repository.dart';
import 'features/ministry/data/ministry_handoff_repository.dart';
import 'features/ministry/data/ministry_repository.dart';
import 'features/ministry/ui/attendance_page.dart';
import 'features/ministry/ui/classes_page.dart';
import 'features/ministry/ui/convert_handoff_page.dart';
import 'features/ministry/ui/ministry_home_page.dart';
import 'features/ministry/ui/students_page.dart';
import 'features/ministry/ui/team_page.dart';
import 'ui/unified_theme.dart';

enum _DirectoryNavigation { first, next, previous }

class App extends StatelessWidget {
  const App({
    super.key,
    this.configuration,
    this.auth,
    this.publicIntakeRepository,
    this.turnstileChallengeFactory,
    this.initialPath,
    this.browserRouteHistoryFactory,
  });

  final Configuration? configuration;
  final AuthRepository? auth;
  final PublicIntakeRepository? publicIntakeRepository;
  final TurnstileChallengeFactory? turnstileChallengeFactory;
  final String? initialPath;
  final BrowserRouteHistory Function()? browserRouteHistoryFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IEADPE — Novos Convertidos',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildUnifiedTheme(),
      home: _BootstrapScreen(
        configuration: configuration,
        auth: auth,
        publicIntakeRepository: publicIntakeRepository,
        turnstileChallengeFactory: turnstileChallengeFactory,
        initialPath: initialPath,
        browserRouteHistoryFactory: browserRouteHistoryFactory,
      ),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen({
    this.configuration,
    this.auth,
    this.publicIntakeRepository,
    this.turnstileChallengeFactory,
    this.initialPath,
    this.browserRouteHistoryFactory,
  });

  final Configuration? configuration;
  final AuthRepository? auth;
  final PublicIntakeRepository? publicIntakeRepository;
  final TurnstileChallengeFactory? turnstileChallengeFactory;
  final String? initialPath;
  final BrowserRouteHistory Function()? browserRouteHistoryFactory;

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  AuthRepository? _auth;
  PublicIntakeRepository? _publicIntakeRepository;
  BrowserRouteHistory? _browserHistory;
  TurnstileChallenge? _publicChallenge;
  String? _intendedRoute;
  bool _ownsPublicRepository = false;
  bool _publicMode = false;
  bool _loading = false;

  Configuration get _configuration =>
      widget.configuration ?? Configuration.fromEnvironment();

  TurnstileChallenge _newChallenge() =>
      (widget.turnstileChallengeFactory ?? createTurnstileChallenge)();

  @override
  void initState() {
    super.initState();
    final path = widget.initialPath ?? Uri.base.path;
    _publicMode = isPublicRegistrationPath(path);
    _intendedRoute = widget.initialPath == null ? null : safeRoute(path);
    _browserHistory =
        (widget.browserRouteHistoryFactory ?? createBrowserRouteHistory)();
    _browserHistory!.listen(_browserPathChanged);
    _publicIntakeRepository = widget.publicIntakeRepository;
    if (_publicIntakeRepository == null && _configuration.isValid) {
      _publicIntakeRepository = PublicIntakeRepository(
        supabaseUrl: Uri.parse(_configuration.supabaseUrl),
        publishableKey: _configuration.supabasePublishableKey,
      );
      _ownsPublicRepository = true;
    }
    if (_publicMode) {
      // Public registration does not initialize Supabase or protected owners.
      _auth = widget.auth;
      return;
    }
    if (widget.auth != null) {
      _auth = widget.auth;
      return;
    }
    unawaited(_initialize());
  }

  Future<void> _initialize({String? intendedRoute}) async {
    if (_auth != null || _loading) return;
    final configuration = _configuration;
    if (!configuration.isValid) return;
    setState(() => _loading = true);
    try {
      // Trusted deployment setting, never inferred from an incoming callback.
      final callback = kIsWeb
          ? const String.fromEnvironment('AUTH_CALLBACK_URL')
          : AuthRedirectPolicy.androidCallback;
      final auth = await AuthRepository.initialize(
        configuration,
        AuthRedirectPolicy(Uri.parse(callback)),
      );
      if (mounted) {
        setState(() {
          _auth = auth;
          _intendedRoute = intendedRoute ?? _intendedRoute;
        });
      }
    } catch (_) {
      // Configuration and provider details belong in operator documentation.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showProtectedRoute(String destination, {required bool pushHistory}) {
    if (pushHistory) _browserHistory?.push(destination);
    setState(() {
      _publicMode = false;
      _publicChallenge = null;
      _intendedRoute = destination;
      if (widget.auth != null) _auth = widget.auth;
    });
    if (_auth == null) unawaited(_initialize(intendedRoute: destination));
  }

  void _openProtectedRoute(String route) {
    final destination = safeRoute(route);
    if (isPublicRegistrationPath(destination)) return;
    _showProtectedRoute(destination, pushHistory: true);
  }

  void _browserPathChanged(String path) {
    if (!mounted) return;
    final destination = safeRoute(path);
    if (destination != path) _browserHistory?.replace(destination);
    if (isPublicRegistrationPath(destination)) {
      if (_publicMode) {
        _intendedRoute = destination;
        return;
      }
      setState(() {
        _publicMode = true;
        _publicChallenge = _newChallenge();
        _intendedRoute = destination;
        _loading = false;
      });
      return;
    }
    if (_publicMode) _showProtectedRoute(destination, pushHistory: false);
  }

  Future<void> _returnToPublicRegistration() async {
    _browserHistory?.replace('/register');
    setState(() {
      _publicMode = true;
      _intendedRoute = '/register';
      _loading = false;
      _publicChallenge = _newChallenge();
    });
  }

  @override
  void dispose() {
    _browserHistory?.dispose();
    if (_ownsPublicRepository) _publicIntakeRepository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_publicMode) {
      _publicChallenge ??= _newChallenge();
      return PublicRegistrationPage(
        repository: _publicIntakeRepository,
        challenge: _publicChallenge!,
        onNavigateToProtected: _openProtectedRoute,
      );
    }
    if (_auth != null) {
      return ProtectedApplication(
        repository: _auth!,
        intendedRoute: _intendedRoute,
        publicIntakeRepository: _publicIntakeRepository,
        turnstileChallengeFactory: widget.turnstileChallengeFactory,
        onSignedOut: _returnToPublicRegistration,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('IEADPE')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 512),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.church, size: 48, color: Color(0xff1e3a5f)),
                  const SizedBox(height: 16),
                  Text(
                    'Novos Convertidos',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loading ? 'Preparando acesso…' : 'Serviço indisponível',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Não foi possível disponibilizar o acesso. Tente novamente ou procure a liderança para obter ajuda.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : () => _initialize(intendedRoute: _intendedRoute),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// All repositories and protected widget owners share this lifetime boundary.
class ProtectedApplication extends StatefulWidget {
  const ProtectedApplication({
    super.key,
    required this.repository,
    this.pickPhoto,
    this.intendedRoute,
    this.publicIntakeRepository,
    this.turnstileChallengeFactory,
    this.onSignedOut,
  });
  final AuthRepository repository;
  final Future<Uint8List?> Function()? pickPhoto;
  final String? intendedRoute;
  final PublicIntakeRepository? publicIntakeRepository;
  final TurnstileChallengeFactory? turnstileChallengeFactory;
  final Future<void> Function()? onSignedOut;
  @override
  State<ProtectedApplication> createState() => _ProtectedApplicationState();
}

class _ProtectedApplicationState extends State<ProtectedApplication> {
  final _boundary = ProtectedDataBoundary();
  GlobalKey<NavigatorState> _protectedNavigatorKey =
      GlobalKey<NavigatorState>();
  int? _protectedNavigatorGeneration;
  late final SupabaseGateway _gateway;
  late final SessionRouter _router;
  late final ConvertRepository _converts;
  late final PhotoRepository _photos;
  late final HomeRepository _home;
  late final WeeklyRepository _weekly;
  late final ReportsRepository _reports;
  late final BackupRepository _backup;
  late final FeedbackRepository _feedback;
  late final FileExporter _exporter;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 100;
    cache.maximumSizeBytes = 16 * 1024 * 1024;
    _gateway = SupabaseGateway(widget.repository.client, _boundary);
    _converts = ConvertRepository(_gateway);
    _photos = PhotoRepository(_gateway);
    _home = HomeRepository(_converts);
    _weekly = WeeklyRepository(_gateway);
    _reports = ReportsRepository(_gateway);
    _backup = BackupRepository(_gateway, createImportProgressStore());
    _feedback = FeedbackRepository(_gateway);
    final incoming = Uri.base;
    final policy = widget.repository.redirectPolicy;
    final intended =
        widget.intendedRoute ??
        (policy.accepts(incoming)
            ? policy.intendedFrom(incoming)
            : safeRoute(incoming.path));
    _router = SessionRouter(
      widget.repository,
      clearProtectedCaches: () {
        _boundary.invalidate();
        cache.clear();
        cache.clearLiveImages();
        // notifyListeners below removes the complete keyed subtree this frame.
      },
      intendedRoute: intended,
    );
    _router.addListener(_changed);
    _exporter = createFileExporter(beforeWrite: _validateExternalReturn);
  }

  void _changed() {
    if (!_disposing && mounted) setState(() {});
  }

  Future<void> _validateExternalReturn() async {
    await _router.revalidate();
    await _router.ensureValidated();
  }

  Future<Uint8List?> _pickPhoto() async {
    final token = _gateway.context;
    final bytes = await widget.pickPhoto?.call();
    await _validateExternalReturn();
    _gateway.ensureCurrent(token);
    return bytes;
  }

  Future<void> _signOut() async {
    await _router.signOut();
    if (mounted) await widget.onSignedOut?.call();
  }

  @override
  void dispose() {
    _disposing = true;
    _router.removeListener(_changed);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = _router.protectedGeneration;
    if (_protectedNavigatorGeneration != generation) {
      _protectedNavigatorKey = GlobalKey<NavigatorState>();
      _protectedNavigatorGeneration = generation;
    }
    final scope = _router.scope;
    if (scope == null) {
      if (_router.isChecking) {
        return const Scaffold(body: Center(child: Text('Atualizando acesso…')));
      }
      if (_router.unavailable) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível atualizar seu acesso.'),
                FilledButton(
                  onPressed: _router.refresh,
                  child: const Text('Tentar novamente'),
                ),
                TextButton(onPressed: _signOut, child: const Text('Sair')),
              ],
            ),
          ),
        );
      }
      return LoginPage(
        auth: widget.repository,
        intendedRoute: widget.intendedRoute ?? safeRoute(Uri.base.path),
      );
    }
    return Stack(
      children: [
        Offstage(
          offstage: _router.isChecking,
          child: ExcludeFocus(
            excluding: _router.isChecking,
            child: IgnorePointer(
              ignoring: _router.isChecking,
              child: NavigatorPopHandler<Object?>(
                onPopWithResult: (_) =>
                    _protectedNavigatorKey.currentState?.maybePop(),
                child: SizedBox.expand(
                  child: Navigator(
                    key: _protectedNavigatorKey,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => _ProtectedFeatures(
                        scope: scope,
                        displayName: sessionDisplayName(
                          widget.repository.currentSession?.user.userMetadata,
                        ),
                        router: _router,
                        gateway: _gateway,
                        converts: _converts,
                        photos: _photos,
                        home: _home,
                        weekly: _weekly,
                        reports: _reports,
                        backup: _backup,
                        feedback: _feedback,
                        exporter: _exporter,
                        pickPhoto: widget.pickPhoto == null ? null : _pickPhoto,
                        publicIntakeRepository: widget.publicIntakeRepository,
                        turnstileChallengeFactory:
                            widget.turnstileChallengeFactory,
                        onSignOut: _signOut,
                        onCongregationChanged: _clearNestedRoutes,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_router.isChecking)
          const Positioned.fill(
            child: Scaffold(body: Center(child: Text('Atualizando acesso…'))),
          ),
      ],
    );
  }

  void _clearNestedRoutes() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _protectedNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }
}

class _ProtectedFeatures extends StatefulWidget {
  const _ProtectedFeatures({
    required this.scope,
    required this.displayName,
    required this.router,
    required this.gateway,
    required this.converts,
    required this.photos,
    required this.home,
    required this.weekly,
    required this.reports,
    required this.backup,
    required this.feedback,
    required this.exporter,
    required this.pickPhoto,
    required this.publicIntakeRepository,
    required this.turnstileChallengeFactory,
    required this.onSignOut,
    required this.onCongregationChanged,
  });
  final AccessScope scope;
  final String? displayName;
  final SessionRouter router;
  final SupabaseGateway gateway;
  final ConvertRepository converts;
  final PhotoRepository photos;
  final HomeRepository home;
  final WeeklyRepository weekly;
  final ReportsRepository reports;
  final BackupRepository backup;
  final FeedbackRepository feedback;
  final FileExporter exporter;
  final Future<Uint8List?> Function()? pickPhoto;
  final PublicIntakeRepository? publicIntakeRepository;
  final TurnstileChallengeFactory? turnstileChallengeFactory;
  final Future<void> Function() onSignOut;
  final VoidCallback onCongregationChanged;
  @override
  State<_ProtectedFeatures> createState() => _ProtectedFeaturesState();
}

class _ProtectedFeaturesState extends State<_ProtectedFeatures> {
  List<Congregation>? _catalog;
  List<MinistryCongregationChoice>? _ministryCongregations;
  MinistryCongregationDirectoryPager? _ministryDirectoryPager;
  String? _selectedMinistryCongregationId;
  String? _selectedMinistryCongregationName;
  String? _ministryCatalogError;
  _DirectoryNavigation _ministryCatalogRetryNavigation =
      _DirectoryNavigation.first;
  bool _ministryCatalogLoading = false;
  bool _ministryCatalogRetryNeeded = false;
  bool _catalogLoading = false;
  String? _error;
  String? _overlay;
  MinistryRouteContext? _studentRegistrationContext;

  bool get _usesPublicRegistrationCatalog =>
      widget.router.route == '/register' &&
      !widget.scope.isGlobalManager &&
      widget.scope.congregationIds.isEmpty;
  @override
  void initState() {
    super.initState();
    final ids = widget.scope.ministryCongregationIds.toList()..sort();
    if (!widget.scope.isMinistrySupervision && ids.length == 1) {
      _selectedMinistryCongregationId = ids.single;
    }
    if (widget.scope.hasMinistryAccess) {
      unawaited(_loadMinistryCongregations());
    }
    if (!widget.router.route.startsWith('/ministry')) _load();
  }

  @override
  void didUpdateWidget(covariant _ProtectedFeatures oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _studentRegistrationContext = null;
      _selectedMinistryCongregationId = null;
      _selectedMinistryCongregationName = null;
      _ministryCongregations = null;
      _ministryDirectoryPager = null;
      _ministryCatalogError = null;
      final ids = widget.scope.ministryCongregationIds.toList()..sort();
      if (!widget.scope.isMinistrySupervision && ids.length == 1) {
        _selectedMinistryCongregationId = ids.single;
      }
      if (widget.scope.hasMinistryAccess) {
        if (_ministryCatalogLoading) {
          _ministryCatalogRetryNeeded = true;
        } else {
          unawaited(_loadMinistryCongregations());
        }
      }
    }
  }

  Future<void> _loadMinistryCongregations() async {
    await _navigateMinistryCatalog(_DirectoryNavigation.first);
  }

  Future<void> _navigateMinistryCatalog(_DirectoryNavigation navigation) async {
    if (_ministryCatalogLoading) return;
    _ministryCatalogLoading = true;
    final token = widget.gateway.context;
    if (mounted) {
      setState(() {
        _ministryCatalogError = null;
        _ministryCatalogLoading = true;
        _ministryCatalogRetryNavigation = navigation;
      });
    }
    try {
      final pager = _ministryDirectoryPager ??=
          MinistryCongregationDirectoryPager(
            MinistryBrowserRepository(widget.gateway),
          );
      final page = switch (navigation) {
        _DirectoryNavigation.first => await pager.loadFirst(),
        _DirectoryNavigation.next => await pager.next(),
        _DirectoryNavigation.previous => await pager.previous(),
      };
      if (page == null) return;
      widget.gateway.ensureCurrent(token);
      if (mounted) {
        setState(() {
          _ministryCongregations = page.items;
          if (_selectedMinistryCongregationName == null &&
              _selectedMinistryCongregationId != null) {
            _selectedMinistryCongregationName = page.items
                .where((item) => item.id == _selectedMinistryCongregationId)
                .firstOrNull
                ?.name;
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      try {
        widget.gateway.ensureCurrent(token);
      } catch (_) {
        return;
      }
      if (error is DataFailure && error.code == 'permission') {
        await widget.router.refresh();
      } else {
        setState(
          () => _ministryCatalogError =
              'Não foi possível carregar as congregações autorizadas.',
        );
      }
    } finally {
      _ministryCatalogLoading = false;
      if (mounted) {
        final retryNeeded = _ministryCatalogRetryNeeded;
        _ministryCatalogRetryNeeded = false;
        setState(() => _ministryCatalogLoading = false);
        if (retryNeeded) unawaited(_loadMinistryCongregations());
      }
    }
  }

  Future<void> _load() async {
    if (_catalogLoading) return;
    _catalogLoading = true;
    final token = widget.gateway.context;
    if (mounted) setState(() => _error = null);
    try {
      late final List<Congregation> rows;
      if (_usesPublicRegistrationCatalog) {
        final publicRepository = widget.publicIntakeRepository;
        if (publicRepository == null) {
          throw StateError('Public registration catalog unavailable');
        }
        rows = await orderCongregations([
          for (final item in await publicRepository.listAllCongregations())
            Congregation(id: item.id, name: item.name),
        ]);
      } else {
        rows = await CongregationRepository(widget.gateway).list();
      }
      widget.gateway.ensureCurrent(token);
      if (mounted) setState(() => _catalog = rows);
    } catch (error) {
      if (!mounted) return;
      try {
        widget.gateway.ensureCurrent(token);
      } catch (_) {
        return;
      }
      if (error is DataFailure && error.code == 'permission') {
        await widget.router.refresh();
      } else {
        setState(
          () => _error =
              'Não foi possível carregar as congregações. Tente novamente.',
        );
      }
    } finally {
      _catalogLoading = false;
    }
  }

  @override
  void dispose() {
    _catalog = null;
    _overlay = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    if (widget.router.route.startsWith('/ministry')) {
      page = _ministryPage();
    } else if (_overlay == 'submit') {
      page = FeedbackDialog(
        repository: widget.feedback,
        onClose: () => setState(() => _overlay = null),
        onScopeRefresh: widget.router.refresh,
      );
    } else if (_overlay == 'manage' && widget.scope.isGlobalManager) {
      page = FeedbackManager(
        repository: widget.feedback,
        onClose: () => setState(() => _overlay = null),
        onScopeRefresh: widget.router.refresh,
      );
    } else if (_catalog == null) {
      page = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Carregando congregações…'),
            if (_error != null)
              TextButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      );
    } else {
      page = switch (widget.router.route) {
        '/home' => HomePage(
          repository: widget.home,
          weekly: widget.weekly,
          onNavigate: widget.router.go,
          name: widget.displayName,
          isAdmin: widget.scope.isGlobalManager,
          onScopeRefresh: widget.router.refresh,
          refreshRevision: widget.router.refreshRevision,
        ),
        '/converts' => ConvertsPage(
          scope: widget.scope,
          converts: widget.converts,
          photos: widget.photos,
          congregations: _catalog!,
          onScopeRefresh: widget.router.refresh,
          pickPhoto: widget.pickPhoto,
          revalidatePhotoAuthority: (congregationId) async {
            await widget.router.revalidate();
            await widget.router.ensureValidated();
            return widget.router.scope?.canAccess(congregationId) ?? false;
          },
        ),
        '/admin' => AdminPage(
          scope: widget.scope,
          gateway: widget.gateway,
          onScopeRefresh: widget.router.refresh,
          onOpenTeam: () => widget.router.go('/ministry/team'),
          reportBuilder: (_) => ConversionPanel(
            repository: widget.reports,
            exporter: widget.exporter,
            onScopeRefresh: widget.router.refresh,
          ),
          eventsBuilder: (_) => EventsPanel(
            repository: widget.reports,
            exporter: widget.exporter,
            onScopeRefresh: widget.router.refresh,
          ),
          backupBuilder: (_) => BackupPanel(
            repository: widget.backup,
            exporter: widget.exporter,
            onScopeRefresh: widget.router.refresh,
          ),
          onFeedback: () => setState(() => _overlay = 'manage'),
        ),
        '/pending' => PendingReviewPage(
          key: ValueKey('pending-review:${widget.scope.hashCode}'),
          repository: PendingSubmissionRepository(widget.gateway),
          scope: widget.scope,
          congregations: _catalog!
              .where(
                (congregation) =>
                    congregation.archivedAt == null &&
                    (widget.scope.isGlobalManager ||
                        widget.scope.congregationIds.contains(congregation.id)),
              )
              .toList(growable: false),
          onScopeRefresh: widget.router.refresh,
          acquireNavigationLock: widget.router.acquireNavigationLock,
          releaseNavigationLock: widget.router.releaseNavigationLock,
        ),
        _ => RegisterPage(
          converts: widget.converts,
          photos: widget.photos,
          congregations: _catalog!.where((c) => c.archivedAt == null).toList(),
          pickPhoto: widget.pickPhoto,
          scope: widget.scope,
          publicIntakeRepository: widget.publicIntakeRepository,
          turnstileChallengeFactory: widget.turnstileChallengeFactory,
          revalidateScope: (congregationId) async {
            await widget.router.revalidate();
            await widget.router.ensureValidated();
            return widget.router.scope?.canAccess(congregationId) ?? false;
          },
          revalidatePhotoAuthority: (congregationId) async {
            await widget.router.revalidate();
            await widget.router.ensureValidated();
            return widget.router.scope?.canAccess(congregationId) ?? false;
          },
          onCancel: () => widget.router.go('/home'),
        ),
      };
    }
    return AppShell(
      scope: widget.scope,
      currentRoute: widget.router.route,
      navigationLocked: widget.router.navigationLocked,
      onNavigate: (route) {
        if (widget.router.navigationLocked) return;
        setState(() => _overlay = null);
        if (!route.startsWith('/ministry') && _catalog == null) _load();
        widget.router.go(route);
      },
      onSignOut: () => unawaited(widget.onSignOut()),
      onFeedback: () => setState(() => _overlay = 'submit'),
      child: page,
    );
  }

  Widget _ministryPage() {
    final ministry = MinistryRepository(widget.gateway);
    final browser = MinistryBrowserRepository(widget.gateway);
    final handoff = MinistryHandoffRepository(widget.gateway);
    final ids = widget.scope.ministryCongregationIds.toList()..sort();
    // Until the server directory has loaded, expose no choices. In particular,
    // never turn a grant UUID into a user-facing name or enable a scoped query
    // from an unlabelled fallback entry.
    final available = visibleCongregationChoices(
      page: _ministryCongregations ?? const <MinistryCongregationChoice>[],
      selectedId: _selectedMinistryCongregationId,
      selectedName: _selectedMinistryCongregationName,
    );
    final selectedId = _selectedMinistryCongregationId;
    final selectedOnPage = selectedId == null
        ? null
        : available.where((item) => item.id == selectedId).firstOrNull;
    final congregationId = _selectedMinistryCongregationName == null
        ? null
        : selectedId;
    final scopeName =
        _selectedMinistryCongregationName ?? 'Selecione uma congregação';
    final scopedActionsEnabled =
        congregationId != null &&
        widget.scope.canAccessMinistry(congregationId);
    final registrationContext = _studentRegistrationContext;
    final registrationContextValid =
        registrationContext != null &&
        registrationContext.hasValidIds &&
        registrationContext.congregationId == congregationId &&
        widget.scope.canAccessMinistry(registrationContext.congregationId);
    if (widget.router.route == '/ministry/students/register' &&
        !registrationContextValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.router.route == '/ministry/students/register') {
          widget.router.go(safeRoute(widget.router.route));
        }
      });
      return const Center(child: Text('Cadastro de aluno indisponível.'));
    }
    if (!widget.scope.isMinistrySupervision &&
        widget.router.route != '/ministry' &&
        !scopedActionsEnabled) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecione uma congregação autorizada antes de continuar.',
              ),
              TextButton(
                onPressed: () => widget.router.go('/ministry'),
                child: const Text('Escolher congregação'),
              ),
            ],
          ),
        ),
      );
    }
    return switch (widget.router.route) {
      '/ministry' => MinistryHomePage(
        key: ValueKey('ministry-home:$congregationId'),
        loadOverview: () =>
            ministry.getOverview(congregationId: congregationId),
        scopeName: scopeName,
        availableCongregationIds: [for (final item in available) item.id],
        congregationNames: {for (final item in available) item.id: item.name},
        selectedCongregationId: selectedOnPage?.id,
        hasPreviousCongregationPage:
            _ministryDirectoryPager?.hasPrevious ?? false,
        hasNextCongregationPage: _ministryDirectoryPager?.hasNext ?? false,
        congregationPageNumber: _ministryDirectoryPager?.pageNumber ?? 1,
        onPreviousCongregationPage: _ministryCatalogLoading
            ? null
            : () => _navigateMinistryCatalog(_DirectoryNavigation.previous),
        onNextCongregationPage: _ministryCatalogLoading
            ? null
            : () => _navigateMinistryCatalog(_DirectoryNavigation.next),
        scopeLoading: _ministryCatalogLoading,
        scopeError: _ministryCatalogError,
        onRetryScope: () =>
            _navigateMinistryCatalog(_ministryCatalogRetryNavigation),
        onSelectCongregation: (value) {
          setState(() {
            _selectedMinistryCongregationId = value;
            _selectedMinistryCongregationName = value == null
                ? null
                : available.where((item) => item.id == value).firstOrNull?.name;
          });
          widget.onCongregationChanged();
        },
        scopedActionsEnabled: scopedActionsEnabled,
        scopeRequired:
            !widget.scope.isMinistrySupervision &&
            ids.length > 1 &&
            congregationId == null,
        onOpenStudents: scopedActionsEnabled
            ? () => widget.router.go('/ministry/students')
            : null,
        onOpenClasses: scopedActionsEnabled
            ? () => widget.router.go('/ministry/classes')
            : null,
        onOpenAttendance:
            scopedActionsEnabled || widget.scope.isMinistrySupervision
            ? () => widget.router.go('/ministry/attendance')
            : null,
      ),
      '/ministry/team' => TeamPage(
        key: ValueKey('ministry-team:$congregationId'),
        repository: ministry,
        congregationId: congregationId,
        supervision:
            widget.scope.isMinistrySupervision && congregationId == null,
        canManageAccess:
            widget.scope.isGlobalManager || widget.scope.isMinistrySupervision,
        onScopeRefresh: widget.router.refresh,
      ),
      '/ministry/students' when scopedActionsEnabled => StudentsPage(
        key: ValueKey('ministry-students:$congregationId'),
        repository: browser,
        congregationId: congregationId,
        onOpenHandoff: () => widget.router.go('/ministry/handoff'),
        onRegister: () => _openStudentRegistration(congregationId),
      ),
      '/ministry/students/register'
          when scopedActionsEnabled && registrationContextValid =>
        StudentRegistrationPage(
          key: ValueKey(
            'ministry-student-register:${registrationContext.congregationId}',
          ),
          repository: ministry,
          congregationId: registrationContext.congregationId,
          onCancel: _returnFromStudentRegistration,
          onSaved: (_) => _returnFromStudentRegistration(),
        ),
      '/ministry/classes' when scopedActionsEnabled => ClassesPage(
        key: ValueKey('ministry-classes:$congregationId'),
        repository: browser,
        congregationId: congregationId,
      ),
      '/ministry/attendance' when scopedActionsEnabled => AttendancePage(
        key: ValueKey('ministry-attendance:$congregationId'),
        repository: ministry,
        congregationId: congregationId,
      ),
      '/ministry/attendance' when widget.scope.isMinistrySupervision =>
        AttendancePage(repository: ministry),
      '/ministry/handoff' when scopedActionsEnabled => ConvertHandoffPage(
        key: ValueKey('ministry-handoff:$congregationId'),
        congregationId: congregationId,
        canPromote: widget.scope.canAccessMinistry(congregationId),
        handoff: handoff,
        browser: browser,
        ministry: ministry,
      ),
      _ => const Center(
        child: Text('Selecione uma congregação autorizada antes de continuar.'),
      ),
    };
  }

  void _openStudentRegistration(String? congregationId) {
    if (congregationId == null ||
        !widget.scope.canAccessMinistry(congregationId)) {
      return;
    }
    setState(() {
      _studentRegistrationContext = MinistryRouteContext(
        congregationId: congregationId,
        returnTo: MinistryReturnRoute.students,
      );
    });
    widget.router.go('/ministry/students/register');
  }

  Future<void> _returnFromStudentRegistration() async {
    final savedContext = _studentRegistrationContext;
    if (mounted) setState(() => _studentRegistrationContext = null);
    if (savedContext == null || !savedContext.hasValidIds) {
      widget.router.go('/register');
      return;
    }
    try {
      await widget.router.revalidate();
      await widget.router.ensureValidated();
    } catch (_) {
      widget.router.go('/register');
      return;
    }
    final scope = widget.router.scope;
    final target = savedContext.returnTo.path;
    if (scope != null &&
        scope.canAccessMinistry(savedContext.congregationId) &&
        widget.router.allowedRoutes.contains(target)) {
      widget.router.go(target);
    } else {
      widget.router.go('/register');
    }
  }
}
