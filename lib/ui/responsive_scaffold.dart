import 'package:flutter/material.dart';

import 'app_theme.dart';

/// S10 responsive breakpoints.
abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
}

enum AppLayout {
  compact,
  medium,
  expanded;

  static AppLayout fromWidth(double width) {
    if (width >= AppBreakpoints.expanded) {
      return AppLayout.expanded;
    }
    if (width >= AppBreakpoints.medium) {
      return AppLayout.medium;
    }
    return AppLayout.compact;
  }
}

class AppNavDestination {
  const AppNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? semanticLabel;
}

/// Navigation shell that reflows between a persistent rail, a compact rail
/// and a drawer according to [AppBreakpoints].
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final List<Widget> actions;

  static const Key persistentNavKey = Key('app-nav-persistent');
  static const Key compactNavKey = Key('app-nav-compact');
  static const Key drawerKey = Key('app-nav-drawer');
  static const Key openDrawerKey = Key('app-nav-open');
  static const Key contentKey = Key('app-content');

  @override
  Widget build(BuildContext context) {
    final AppLayout layout = AppLayout.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    return switch (layout) {
      AppLayout.expanded => _withRail(
        context,
        persistentNavKey,
        extended: true,
      ),
      AppLayout.medium => _withRail(context, compactNavKey, extended: false),
      AppLayout.compact => _withDrawer(context),
    };
  }

  Widget _withRail(BuildContext context, Key key, {required bool extended}) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NavigationRail(
            key: key,
            extended: extended,
            minWidth: extended ? 80 : 72,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: extended ? null : NavigationRailLabelType.none,
            leading: extended
                ? Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.x4,
                      bottom: AppSpacing.x6,
                    ),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.only(
                      top: AppSpacing.x4,
                      bottom: AppSpacing.x6,
                    ),
                    child: Icon(Icons.church_outlined),
                  ),
            destinations: <NavigationRailDestination>[
              for (final AppNavDestination destination in destinations)
                NavigationRailDestination(
                  icon: Semantics(
                    label: destination.semanticLabel ?? destination.label,
                    child: Icon(destination.icon),
                  ),
                  selectedIcon: Semantics(
                    label: destination.semanticLabel ?? destination.label,
                    child: Icon(destination.selectedIcon ?? destination.icon),
                  ),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: <Widget>[
                if (actions.isNotEmpty) _actionBar(),
                Expanded(child: _content()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        0,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: actions,
        ),
      ),
    );
  }

  Widget _withDrawer(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        leading: Builder(
          builder: (BuildContext context) => IconButton(
            key: openDrawerKey,
            icon: const Icon(Icons.menu),
            tooltip: 'Abrir navegação',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: actions,
      ),
      drawer: Drawer(
        key: drawerKey,
        child: SafeArea(
          child: ListView(
            children: <Widget>[
              for (int index = 0; index < destinations.length; index++)
                ListTile(
                  leading: Icon(destinations[index].icon),
                  title: Text(destinations[index].label),
                  selected: index == selectedIndex,
                  onTap: () {
                    Navigator.of(context).pop();
                    onDestinationSelected(index);
                  },
                ),
            ],
          ),
        ),
      ),
      body: _content(),
    );
  }

  Widget _content() {
    return SafeArea(
      key: contentKey,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: body,
          ),
        ),
      ),
    );
  }
}
