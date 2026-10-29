import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../routing/router.dart';
import '../ui/base44_widgets.dart';
import '../ui/unified_theme.dart';
import 'brand_header.dart';

/// Navigation is presentation only; SessionRouter must authorize every callback.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.scope,
    required this.onNavigate,
    required this.onSignOut,
    this.onSignIn,
    this.currentRoute = '/home',
    this.onFeedback,
    this.publicMode = false,
    this.navigationLocked = false,
  });

  final Widget child;
  final AccessScope scope;
  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignOut;
  final VoidCallback? onSignIn;
  final VoidCallback? onFeedback;
  final bool publicMode;
  final bool navigationLocked;

  static const labels = {
    '/home': 'Início',
    '/register': 'Cadastrar',
    '/converts': 'Convertidos',
    '/pending': 'Pendentes',
    '/admin': 'Admin',
    '/ministry': 'Discipulado',
    '/ministry/team': 'Equipe',
    '/ministry/students': 'Alunos',
    '/ministry/students/register': 'Cadastrar aluno',
    '/ministry/classes': 'Turmas',
    '/ministry/attendance': 'Frequência',
    '/ministry/handoff': 'Encaminhamentos',
  };

  static const icons = {
    '/home': Icons.home_outlined,
    '/register': Icons.person_add_alt_1_outlined,
    '/converts': Icons.people_outline,
    '/pending': Icons.inbox_outlined,
    '/admin': Icons.settings_outlined,
    '/ministry': Icons.menu_book_outlined,
    '/ministry/team': Icons.groups_outlined,
    '/ministry/students': Icons.school_outlined,
    '/ministry/students/register': Icons.person_add_alt_1_outlined,
    '/ministry/classes': Icons.class_outlined,
    '/ministry/attendance': Icons.fact_check_outlined,
    '/ministry/handoff': Icons.move_to_inbox_outlined,
  };

  /// Registration and handoff depend on transient context and are reopened
  /// from their owning page instead of the shell.
  static const hiddenFromMenu = {
    '/ministry/handoff',
    '/ministry/students/register',
  };

  bool _active(String route) =>
      route == currentRoute ||
      (route == '/ministry' && currentRoute.startsWith('/ministry/'));

  List<String> _topLevelRoutes(List<String> routes) => [
    for (final route in const [
      '/home',
      '/register',
      '/converts',
      '/admin',
      '/ministry',
    ])
      if (routes.contains(route)) route,
  ];

  void _feedback(BuildContext context) {
    if (navigationLocked) return;
    if (onFeedback != null) {
      onFeedback!.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O envio de sugestões estará disponível em breve.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = publicMode
        ? const ['/register']
        : routesFor(scope)
              .where((route) => !hiddenFromMenu.contains(route))
              .toList(growable: false);
    final mobile = MediaQuery.sizeOf(context).width < 768;
    final primaryRoutes = _topLevelRoutes(routes);
    final ministryRoutes = [
      for (final route in routes)
        if (route.startsWith('/ministry')) route,
    ];

    Widget desktopRoute(String route) {
      final selected = _active(route);
      return TextButton.icon(
        key: ValueKey('app-shell-nav-$route'),
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          foregroundColor: selected ? UnifiedColors.brandNavy : Colors.white,
          backgroundColor: selected ? Colors.white : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: navigationLocked ? null : () => onNavigate(route),
        icon: Icon(icons[route], size: 18),
        label: Text(
          labels[route]!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final sessionButtonStyle = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );

    Widget sessionAction() {
      if (publicMode) {
        return TextButton.icon(
          key: const ValueKey('app-shell-sign-in'),
          style: sessionButtonStyle,
          onPressed: navigationLocked ? null : onSignIn,
          icon: const Icon(Icons.login_outlined, size: 18),
          label: const Text('Entrar'),
        );
      }
      return TextButton.icon(
        key: const ValueKey('app-shell-sign-out'),
        style: sessionButtonStyle,
        onPressed: onSignOut,
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Sair'),
      );
    }

    Widget ministrySelector() {
      if (ministryRoutes.length < 2) return const SizedBox.shrink();
      final selectedRoute = ministryRoutes.contains(currentRoute)
          ? currentRoute
          : '/ministry';
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Base44Panel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButtonFormField<String>(
                key: const ValueKey('app-shell-ministry-selector'),
                initialValue: selectedRoute,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Seção do Discipulado',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
                items: [
                  for (final route in ministryRoutes)
                    DropdownMenuItem(
                      value: route,
                      child: Text(labels[route]!, maxLines: 2),
                    ),
                ],
                onChanged: navigationLocked
                    ? null
                    : (route) {
                        if (route != null) onNavigate(route);
                      },
              ),
            ),
          ),
        ),
      );
    }

    final textScale = MediaQuery.textScalerOf(context).scale(11);
    final bottomHeight = math.max(68.0, 44 + textScale * 2);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [UnifiedColors.page, UnifiedColors.pageTint],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x241e3a5f),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                width: double.infinity,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 896),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(child: BrandHeader()),
                              sessionAction(),
                            ],
                          ),
                          if (!mobile && !publicMode)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final route in primaryRoutes)
                                    desktopRoute(route),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (scope.hasMinistryAccess) ministrySelector(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 896),
                    child: SizedBox.expand(child: child),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: mobile && !publicMode
          ? SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                elevation: 8,
                child: SizedBox(
                  height: bottomHeight,
                  child: Row(
                    children: [
                      for (final route in primaryRoutes)
                        Expanded(
                          child: Semantics(
                            key: ValueKey('app-shell-nav-$route'),
                            selected: _active(route),
                            button: !navigationLocked,
                            label: labels[route],
                            child: InkWell(
                              onTap: navigationLocked
                                  ? null
                                  : () => onNavigate(route),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icons[route],
                                        size: 22,
                                        color: _active(route)
                                            ? UnifiedColors.brandNavy
                                            : UnifiedColors.muted,
                                      ),
                                      const SizedBox(height: 2),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            labels[route]!,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: _active(route)
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: _active(route)
                                                  ? UnifiedColors.brandNavy
                                                  : UnifiedColors.muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_active(route))
                                    Positioned(
                                      bottom: 0,
                                      left: 14,
                                      right: 14,
                                      child: Container(
                                        height: 4,
                                        decoration: const BoxDecoration(
                                          color: UnifiedColors.brandNavy,
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      floatingActionButton: publicMode
          ? null
          : FloatingActionButton(
              tooltip: 'Enviar sugestão',
              onPressed: navigationLocked ? null : () => _feedback(context),
              child: const Icon(Icons.feedback_outlined),
            ),
    );
  }
}
