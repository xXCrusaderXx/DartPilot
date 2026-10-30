import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_choice.dart';
import '../engine/engine_connection.dart';
import 'connect_screen.dart';
import 'home_screen.dart';
import 'pairing_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import '../engine/camera_order.dart';
import '../engine/setup_status.dart';
import '../theme.dart';

/// The app's root: on the first start the choice of how darts are counted, then the main view. The main view stays
/// while a connection drops or the engine cannot be reached; home says so. Games opened on top of it stay open.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  /// The player asked to change how darts are counted
  bool _choosing = false;

  /// The main view's tab, kept here so that it survives a lost and regained connection
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final settings = EngineSettingsScope.of(context);
    return EngineSelect(
      select: (engine) => (engine.isConnected, engine.pairingRequired),
      builder: (context, state) {
        final (connected, pairingRequired) = state;
        if (connected && pairingRequired) return const PairingScreen();
        if (connected) _choosing = false;
        if (!connected && (_choosing || !settings.chosen)) {
          return ConnectScreen(
            onPlayByHand: () {
              settings.choose(byHand: true);
              setState(() => _choosing = false);
            },
            onCancel: settings.chosen ? () => setState(() => _choosing = false) : null,
          );
        }
        return MainShell(
          index: _tab,
          onIndexChanged: (i) => setState(() => _tab = i),
          onConnect: () => setState(() => _choosing = true),
        );
      },
    );
  }
}

/// Home, statistics and settings, with a navigation bar at the bottom on phones and a rail at the side on wide screens.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.index, required this.onIndexChanged, required this.onConnect});

  final int index;
  final ValueChanged<int> onIndexChanged;

  /// Opens the choice of how darts are counted
  final VoidCallback onConnect;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int get _index => widget.index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = [
      HomeScreen(onConnect: widget.onConnect),
      const StatisticsScreen(),
      SettingsScreen(onConnect: widget.onConnect),
    ];
    final body = IndexedStack(index: _index, children: pages);
    // Back always leads home, and never out of the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) widget.onIndexChanged(0);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: widget.onIndexChanged,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home),
                        label: Text(l10n.navHome),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.bar_chart_outlined),
                        selectedIcon: const Icon(Icons.bar_chart),
                        label: Text(l10n.navStatistics),
                      ),
                      NavigationRailDestination(
                        icon: const _SettingsIcon(Icons.settings_outlined),
                        selectedIcon: const _SettingsIcon(Icons.settings),
                        label: Text(l10n.navSettings),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            );
          }
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: widget.onIndexChanged,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l10n.navHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  selectedIcon: const Icon(Icons.bar_chart),
                  label: l10n.navStatistics,
                ),
                NavigationDestination(
                  icon: const _SettingsIcon(Icons.settings_outlined),
                  selectedIcon: const _SettingsIcon(Icons.settings),
                  label: l10n.navSettings,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The settings tab's icon, with a mark while a setup step needs the player
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final order = CameraOrderScope.of(context);
    return EngineSelect(
      select: (engine) => SetupStatus.of(engine, order).needsAttention,
      builder: (context, attention) => Badge(
        key: const ValueKey('settings-attention'),
        isLabelVisible: attention,
        backgroundColor: StatusColors.of(context).warning,
        child: Icon(icon),
      ),
    );
  }
}
