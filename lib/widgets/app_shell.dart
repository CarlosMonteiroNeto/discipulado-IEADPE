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
    this.currentRoute = '/home',
    this.onFeedback,
  });

  final Widget child;
  final AccessScope scope;
  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignOut;
  final VoidCallback? onFeedback;

  static const labels = {
    '/home': 'Início',
    '/register': 'Cadastrar',
    '/converts': 'Convertidos',
    '/admin': 'Admin',
    '/ministry': 'Discipulado',
    '/ministry/team': 'Equipe',
    '/ministry/students': 'Alunos',
    '/ministry/students/register': 'Cadastrar aluno',
    '/ministry/classes': 'Turmas',
    '/ministry/attendance': 'Frequência',
    '/ministry/handoff': 'Novos convertidos',
  };

  static const icons = {
    '/home': Icons.home_outlined,
    '/register': Icons.person_add_alt_1_outlined,
    '/converts': Icons.people_outline,
    '/admin': Icons.settings_outlined,
    '/ministry': Icons.menu_book_outlined,
    '/ministry/team': Icons.groups_outlined,
    '/ministry/students': Icons.school_outlined,
    '/ministry/classes': Icons.class_outlined,
    '/ministry/attendance': Icons.fact_check_outlined,
    '/ministry/handoff': Icons.move_to_inbox_outlined,
  };

  static const _feedbackAction = '__base44_feedback__';
  static const _signOutAction = '__base44_sign_out__';

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
    final routes = routesFor(scope);
    final mobile = MediaQuery.sizeOf(context).width < 768;
    final hasOverflow = routes.length > 5;
    final primaryRoutes = mobile
        ? (hasOverflow
              ? [
                  for (final route in const [
                    '/home',
                    '/register',
                    '/converts',
                    '/ministry',
                  ])
                    if (routes.contains(route)) route,
                ]
              : routes)
        : _topLevelRoutes(routes);
    final ministryRoutes = [
      for (final route in routes)
        if (route.startsWith('/ministry')) route,
    ];

    Widget menuDrawer(BuildContext drawerContext) => Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(gradient: brandGradient),
              child: Row(
                children: [
                  const ExcludeSemantics(
                    child: Icon(Icons.church, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Menu',
                    style: Theme.of(drawerContext).textTheme.titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final route in routes)
                    ListTile(
                      key: ValueKey('app-shell-drawer-$route'),
                      minVerticalPadding: 8,
                      leading: ExcludeSemantics(child: Icon(icons[route])),
                      title: Text(labels[route]!),
                      selected: _active(route),
                      selectedColor: UnifiedColors.brandNavy,
                      selectedTileColor: UnifiedColors.selected,
                      onTap: () {
                        Navigator.of(drawerContext).pop();
                        onNavigate(route);
                      },
                    ),
                  const Divider(),
                  ListTile(
                    key: const ValueKey('app-shell-drawer-feedback'),
                    leading: const Icon(Icons.feedback_outlined),
                    title: const Text('Enviar sugestão'),
                    onTap: () {
                      Navigator.of(drawerContext).pop();
                      _feedback(drawerContext);
                    },
                  ),
                  ListTile(
                    key: const ValueKey('app-shell-drawer-sign-out'),
                    leading: const Icon(Icons.logout),
                    title: const Text('Sair'),
                    onTap: () {
                      Navigator.of(drawerContext).pop();
                      onSignOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

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
        onPressed: () => onNavigate(route),
        icon: Icon(icons[route], size: 18),
        label: Text(
          labels[route]!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    Widget desktopMenu() => PopupMenuButton<String>(
      tooltip: 'Abrir menu',
      onSelected: (value) {
        if (value == _feedbackAction) {
          _feedback(context);
        } else if (value == _signOutAction) {
          onSignOut();
        } else {
          onNavigate(value);
        }
      },
      itemBuilder: (context) => [
        for (final route in routes)
          PopupMenuItem<String>(
            value: route,
            child: Row(
              children: [
                Icon(icons[route], size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(labels[route]!)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: _feedbackAction,
          child: Row(
            children: [
              Icon(Icons.feedback_outlined, size: 20),
              SizedBox(width: 12),
              Text('Enviar sugestão'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: _signOutAction,
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 12),
              Text('Sair'),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.more_horiz, color: Colors.white),
      ),
    );

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
                onChanged: (route) {
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
      endDrawer: mobile ? menuDrawer(context) : null,
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
                              if (mobile)
                                Builder(
                                  builder: (context) => IconButton(
                                    key: const ValueKey('app-shell-open-menu'),
                                    tooltip: 'Abrir menu',
                                    color: Colors.white,
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(48, 48),
                                    ),
                                    onPressed: () =>
                                        Scaffold.of(context).openEndDrawer(),
                                    icon: const Icon(Icons.menu),
                                  ),
                                )
                              else ...[
                                IconButton(
                                  tooltip: 'Sair',
                                  color: Colors.white,
                                  onPressed: onSignOut,
                                  icon: const Icon(Icons.logout),
                                ),
                              ],
                            ],
                          ),
                          if (!mobile)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final route in primaryRoutes)
                                    desktopRoute(route),
                                  if (hasOverflow) desktopMenu(),
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
      bottomNavigationBar: mobile
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
                            button: true,
                            label: labels[route],
                            child: InkWell(
                              onTap: () => onNavigate(route),
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
                      if (hasOverflow)
                        Expanded(
                          child: Builder(
                            builder: (context) => Semantics(
                              button: true,
                              label: 'Menu',
                              child: InkWell(
                                key: const ValueKey('app-shell-bottom-menu'),
                                onTap: () =>
                                    Scaffold.of(context).openEndDrawer(),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.menu,
                                      size: 22,
                                      color: UnifiedColors.muted,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Menu',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: UnifiedColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Enviar sugestão',
        onPressed: () => _feedback(context),
        child: const Icon(Icons.feedback_outlined),
      ),
    );
  }
}
