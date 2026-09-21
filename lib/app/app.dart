/// The composed application widget (S01, S10, S11).
///
/// It owns the session lifecycle: [AuthController] is started once, the router
/// reacts to auth changes, and a missing/inactive profile is replaced by the
/// access-denied screen instead of protected content.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/access_denied_page.dart';
import '../features/auth/auth_controller.dart';
import '../ui/app_theme.dart';
import 'dependencies.dart';

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _supportedLocales = <Locale>[Locale('pt', 'BR')];
const _locale = Locale('pt', 'BR');

class DiscipuladoApp extends StatefulWidget {
  const DiscipuladoApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<DiscipuladoApp> createState() => _DiscipuladoAppState();
}

class _DiscipuladoAppState extends State<DiscipuladoApp> {
  @override
  void initState() {
    super.initState();
    widget.dependencies.authController
      ..addListener(_onAuthChanged)
      ..start();
  }

  @override
  void dispose() {
    widget.dependencies.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Disposes the previous session's controllers as soon as authorization ends
  /// or a different profile/scope arrives (S04, S12).
  void _onAuthChanged() {
    if (!widget.dependencies.authController.state.isAuthorized) {
      widget.dependencies.disposeSessionControllers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = widget.dependencies.authController;
    return ListenableBuilder(
      listenable: auth,
      builder: (BuildContext context, Widget? _) {
        if (auth.state.status == AuthStatus.accessDenied) {
          return MaterialApp(
            title: 'Discipulado IEADPE',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: AccessDeniedPage(controller: auth),
            localizationsDelegates: _localizationsDelegates,
            supportedLocales: _supportedLocales,
            locale: _locale,
          );
        }
        return MaterialApp.router(
          title: 'Discipulado IEADPE',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: widget.dependencies.router,
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: _supportedLocales,
          locale: _locale,
        );
      },
    );
  }
}
