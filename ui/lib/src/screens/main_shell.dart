import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import 'connect_screen.dart';
import 'home_screen.dart';
import 'pairing_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

/// The app's root: the connection page until an engine is connected (or the player chose to play without one), then
/// the main view. A lost connection leads back to the connection page; games opened on top of it stay open.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool _offline = false;

  /// The main view's tab, kept here so that it survives a lost and regained connection
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return EngineSelect(
      select: (engine) => (engine.isConnected, engine.pairingRequired),
      builder: (context, state) {
        final (connected, pairingRequired) = state;
        if (!connected && !_offline) return ConnectScreen(onPlayOffline: () => setState(() => _offline = true));
        if (connected && pairingRequired) return const PairingScreen();
        return MainShell(
          connected: connected,
          index: _tab,
          onIndexChanged: (i) => setState(() => _tab = i),
          onConnect: () => setState(() => _offline = false),
        );
      },
    );
  }
}

/// Home, statistics and settings, with a navigation bar at the bottom on phones and a rail at the side on wide screens.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.connected,
    required this.index,
    required this.onIndexChanged,
    required this.onConnect,
  });

  final bool connected;
  final int index;
  final ValueChanged<int> onIndexChanged;

  /// Back to the connection page, when playing without an engine
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
    final connected = widget.connected;
    // Back always leads home; from home it leads to the connection page only while no engine is connected, and
    // never out of the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          widget.onIndexChanged(0);
        } else if (!connected) {
          widget.onConnect();
        }
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
                        icon: const Icon(Icons.insights_outlined),
                        selectedIcon: const Icon(Icons.insights),
                        label: Text(l10n.navStatistics),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: const Icon(Icons.settings),
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
                  icon: const Icon(Icons.insights_outlined),
                  selectedIcon: const Icon(Icons.insights),
                  label: l10n.navStatistics,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
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
