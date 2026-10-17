import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'configuration.dart';
import 'data/convert_repository.dart';
import 'data/supabase_gateway.dart';
import 'domain/models.dart';
import 'routing/router.dart';
import 'features/auth/login_page.dart';
import 'features/admin/admin_page.dart';
import 'features/admin/congregation_repository.dart';
import 'features/backup/backup_panel.dart';
import 'features/backup/backup_repository.dart';
import 'features/converts/convert_form.dart';
import 'features/converts/converts_page.dart';
import 'features/converts/register_page.dart';
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
  const App({super.key, this.configuration, this.auth});

  final Configuration? configuration;
  final AuthRepository? auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IEADPE — Novos Convertidos',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildUnifiedTheme(),
      home: _BootstrapScreen(configuration: configuration, auth: auth),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen({this.configuration, this.auth});
  final Configuration? configuration;
  final AuthRepository? auth;
  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  AuthRepository? _auth;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.auth != null) {
      _auth = widget.auth;
      return;
    }
    final configuration =
        widget.configuration ?? Configuration.fromEnvironment();
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
      if (mounted) setState(() => _auth = auth);
    } catch (_) {
      // Configuration and provider details belong in operator documentation.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth != null) return ProtectedApplication(repository: _auth!);
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
                    onPressed: _loading ? null : _initialize,
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
    this.pickPhoto = pickConvertPhoto,
  });
  final AuthRepository repository;
  final Future<Uint8List?> Function() pickPhoto;
  @override
  State<ProtectedApplication> createState() => _ProtectedApplicationState();
}

class _ProtectedApplicationState extends State<ProtectedApplication> {
  final _boundary = ProtectedDataBoundary();
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
    final intended = policy.accepts(incoming)
        ? policy.intendedFrom(incoming)
        : safeRoute(incoming.path);
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
    final bytes = await widget.pickPhoto();
    await _validateExternalReturn();
    _gateway.ensureCurrent(token);
    return bytes;
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
                TextButton(
                  onPressed: _router.signOut,
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        );
      }
      return LoginPage(
        auth: widget.repository,
        intendedRoute: safeRoute(Uri.base.path),
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
              child: _ProtectedFeatures(
                key: ValueKey(_gateway.context),
                scope: scope,
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
                pickPhoto: _pickPhoto,
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
}

class _ProtectedFeatures extends StatefulWidget {
  const _ProtectedFeatures({
    super.key,
    required this.scope,
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
  });
  final AccessScope scope;
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
  final Future<Uint8List?> Function() pickPhoto;
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
      final rows = await CongregationRepository(widget.gateway).list();
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
        ),
        '/admin' => AdminPage(
          scope: widget.scope,
          gateway: widget.gateway,
          onScopeRefresh: widget.router.refresh,
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
        _ => RegisterPage(
          converts: widget.converts,
          photos: widget.photos,
          congregations: _catalog!.where((c) => c.archivedAt == null).toList(),
          pickPhoto: widget.pickPhoto,
          onCancel: () => widget.router.go('/home'),
        ),
      };
    }
    return AppShell(
      scope: widget.scope,
      currentRoute: widget.router.route,
      onNavigate: (route) {
        setState(() => _overlay = null);
        if (!route.startsWith('/ministry') && _catalog == null) _load();
        widget.router.go(route);
      },
      onSignOut: widget.router.signOut,
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
    final available =
        _ministryCongregations ?? const <MinistryCongregationChoice>[];
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
        onSelectCongregation: (value) => setState(() {
          _selectedMinistryCongregationId = value;
          _selectedMinistryCongregationName = value == null
              ? null
              : available.where((item) => item.id == value).firstOrNull?.name;
        }),
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
      ),
      '/ministry/students' when scopedActionsEnabled => StudentsPage(
        key: ValueKey('ministry-students:$congregationId'),
        repository: browser,
        congregationId: congregationId,
        onOpenHandoff: () => widget.router.go('/ministry/handoff'),
      ),
      '/ministry/classes' when scopedActionsEnabled => ClassesPage(
        key: ValueKey('ministry-classes:$congregationId'),
        repository: browser,
        congregationId: congregationId,
        onOpenAttendance: () => widget.router.go('/ministry/attendance'),
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
}
