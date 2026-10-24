import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'engine/engine_choice.dart';
import 'engine/engine_connection.dart';
import 'engine/engine_manager.dart';
import 'stats/statistics.dart';
import 'theme.dart';
import 'screens/main_shell.dart';

class DartPilotApp extends StatefulWidget {
  const DartPilotApp({super.key, this.locale, this.engine, this.manager, this.settings, this.statistics});

  /// Fixed locale for tests; the system language otherwise
  final Locale? locale;

  /// Engine connection for tests; the app creates its own otherwise
  final EngineConnection? engine;

  /// Engine on this device and the remembered choice, for tests; the app creates and loads its own otherwise, where
  /// the platform can run the engine
  final EngineManager? manager;
  final EngineSettings? settings;

  /// Played games for the statistics; kept in memory only when none is given (tests), main() gives the stored ones
  final Statistics? statistics;

  @override
  State<DartPilotApp> createState() => _DartPilotAppState();
}

class _DartPilotAppState extends State<DartPilotApp> {
  late final EngineConnection _engine = widget.engine ?? EngineConnection();
  late final EngineManager? _manager =
      widget.manager ?? (widget.engine == null && EngineManager.supported ? EngineManager() : null);
  late EngineSettings _settings = widget.settings ?? EngineSettings();
  late final AppLifecycleListener _lifecycle;
  late final Statistics _statistics = widget.statistics ?? Statistics(MemoryGameStore());

  @override
  void initState() {
    super.initState();
    // The engine this app started must not outlive it.
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _manager?.stop();
        return AppExitResponse.exit;
      },
    );
    if (widget.settings == null && widget.engine == null) _restoreChoice();
  }

  Future<void> _restoreChoice() async {
    final settings = await EngineSettings.load();
    if (!mounted) return;
    setState(() => _settings = settings);
    final manager = _manager;
    if (settings.mode == EngineMode.thisDevice && manager != null) {
      await startLocalEngine(manager, _engine, settings);
    } else {
      _engine.url = settings.url;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (widget.manager == null) _manager?.dispose();
    if (widget.engine == null) _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = _manager;
    final app = MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: widget.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: dartPilotTheme(),
      home: const RootScreen(),
    );
    return EngineScope(
      connection: _engine,
      child: StatisticsScope(
        statistics: _statistics,
        child: manager == null ? app : LocalEngineScope(manager: manager, settings: _settings, child: app),
      ),
    );
  }
}
