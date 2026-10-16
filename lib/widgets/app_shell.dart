import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../routing/router.dart';
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
  };
  static const icons = {
    '/home': Icons.home,
    '/register': Icons.person_add,
    '/converts': Icons.people,
    '/admin': Icons.settings,
  };
  @override
  Widget build(BuildContext context) {
    final routes = routesFor(scope);
    final mobile = MediaQuery.sizeOf(context).width < 768;
    Widget navigation(bool drawer) => Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final route in routes)
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: drawer ? const Color(0xff1e3a5f) : Colors.white,
              backgroundColor: route == currentRoute
                  ? (drawer ? const Color(0xffdbeafe) : Colors.white24)
                  : null,
            ),
            onPressed: () {
              if (drawer) Navigator.pop(context);
              onNavigate(route);
            },
            icon: Icon(icons[route]),
            label: Text(labels[route]!),
          ),
        TextButton.icon(
          onPressed: () {
            if (drawer) Navigator.pop(context);
            onSignOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sair'),
          style: TextButton.styleFrom(
            foregroundColor: drawer ? const Color(0xff1e3a5f) : Colors.white,
          ),
        ),
      ],
    );
    return Scaffold(
      drawer: mobile
          ? Drawer(
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const Text('Menu'), navigation(true)],
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfff8fafc), Color(0xffeff6ff)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(gradient: brandGradient),
                width: double.infinity,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 896),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: BrandHeader()),
                              if (mobile)
                                Builder(
                                  builder: (context) => IconButton(
                                    tooltip: 'Abrir menu',
                                    color: Colors.white,
                                    onPressed: () =>
                                        Scaffold.of(context).openDrawer(),
                                    icon: const Icon(Icons.menu),
                                  ),
                                ),
                            ],
                          ),
                          if (!mobile) navigation(false),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 896),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: mobile
          ? SafeArea(
              child: Material(
                color: Colors.white,
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    for (final route in routes)
                      Semantics(
                        selected: route == currentRoute,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: route == currentRoute
                                ? const Color(0xffdbeafe)
                                : null,
                          ),
                          onPressed: () => onNavigate(route),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icons[route]),
                              Text(labels[route]!),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Enviar sugestão',
        onPressed:
            onFeedback ??
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'O envio de sugestões estará disponível em breve.',
                ),
              ),
            ),
        child: const Icon(Icons.feedback_outlined),
      ),
    );
  }
}
