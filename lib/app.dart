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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff1e3a5f),
          foregroundColor: Colors.white,
        ),
      ),
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
  String? _error;
  String? _overlay;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.gateway.context;
    setState(() => _error = null);
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
    if (_overlay == 'submit') {
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
        widget.router.go(route);
      },
      onSignOut: widget.router.signOut,
      onFeedback: () => setState(() => _overlay = 'submit'),
      child: page,
    );
  }
}
