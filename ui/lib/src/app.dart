import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'display.dart';
import 'engine/camera_order.dart';
import 'engine/engine_choice.dart';
import 'engine/engine_connection.dart';
import 'engine/engine_events.dart';
import 'engine/engine_manager.dart';
import 'engine/pairing_tokens.dart';
import 'sound/caller.dart';
import 'stats/dart_links.dart';
import 'stats/statistics.dart';
import 'theme.dart';
import 'screens/main_shell.dart';

class DartPilotApp extends StatefulWidget {
  const DartPilotApp({
    super.key,
    this.locale,
    this.engine,
    this.manager,
    this.settings,
    this.statistics,
    this.cameraOrder,
    this.dartLinks,
    this.caller,
    this.display,
  });

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

  /// The player's order and names of the cameras; kept in memory only when none is given (tests)
  final CameraOrder? cameraOrder;

  /// Which dart set each player throws; kept in memory only when none is given (tests)
  final DartLinks? dartLinks;

  /// The score caller; a silent one when none is given (tests)
  final Caller? caller;

  /// Display style and viewing distance; kept in memory only when none is given (tests)
  final DisplaySettings? display;

  @override
  State<DartPilotApp> createState() => _DartPilotAppState();
}

class _DartPilotAppState extends State<DartPilotApp> {
  late final EngineConnection _engine = widget.engine ?? EngineConnection(tokens: PrefsPairingTokens());
  late final EngineManager? _manager =
      widget.manager ?? (widget.engine == null && EngineManager.supported ? EngineManager() : null);
  late EngineSettings _settings = widget.settings ?? EngineSettings();
  late final AppLifecycleListener _lifecycle;
  late final Statistics _statistics = widget.statistics ?? Statistics(MemoryGameStore());
  late final CameraOrder _cameraOrder = (widget.cameraOrder ?? CameraOrder())..attach(_engine);
  late final DartLinks _dartLinks = widget.dartLinks ?? DartLinks();
  late final Caller _caller = widget.caller ?? Caller(RecordingVoice(), store: false);
  late final DisplaySettings _display = widget.display ?? DisplaySettings(store: false);
  final GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey();
  StreamSubscription<EngineEvent>? _events;
  final Set<String> _movedCameras = {};
  Timer? _movedTimer;
  Timer? _movedQuiet;

  /// Cameras reported within this time are one knock; another notice comes only after [movedQuiet].
  static const Duration movedGather = Duration(seconds: 1);
  static const Duration movedQuiet = Duration(seconds: 15);

  void _showMovedNotice() {
    _movedTimer = null;
    final moved = Set.of(_movedCameras);
    _movedCameras.clear();
    final context = _messenger.currentContext;
    if (moved.isEmpty || context == null || !context.mounted) return;
    _movedQuiet = Timer(movedQuiet, () => _movedQuiet = null);
    final l10n = AppLocalizations.of(context);
    final cameras = _engine.hello?.cameras ?? const <String>[];
    _messenger.currentState?.showSnackBar(
      SnackBar(
        key: const ValueKey('camera-moved'),
        content: Text(
          moved.length > 1
              ? l10n.rigKnockedNotice
              : l10n.cameraMovedNotice(_cameraOrder.label(l10n, cameras, moved.first)),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Shown on whatever page is open: a knocked camera matters during a game as much as in the settings.
    _events = _engine.events.listen((event) {
      if (event is! CameraMoved) return;
      // A knock moves several cameras at once and they sway back a few seconds later: one notice for all of it.
      if (_movedQuiet != null) return;
      _movedCameras.add(event.camera);
      _movedTimer ??= Timer(movedGather, _showMovedNotice);
    });
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
    _events?.cancel();
    _movedTimer?.cancel();
    _movedQuiet?.cancel();
    if (widget.manager == null) _manager?.dispose();
    if (widget.engine == null) _engine.dispose();
    super.dispose();
  }

  static final _darkTheme = dartPilotTheme();
  static final _lightTheme = dartPilotTheme(AppPalette.light);

  @override
  Widget build(BuildContext context) {
    final manager = _manager;
    final app = ListenableBuilder(
      listenable: _display,
      builder: (context, _) => MaterialApp(
        scaffoldMessengerKey: _messenger,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        locale: widget.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: _display.themeMode,
        builder: (context, child) => _ReconnectBanner(child: child!),
        home: const RootScreen(),
      ),
    );
    return EngineScope(
      connection: _engine,
      child: StatisticsScope(
        statistics: _statistics,
        child: CameraOrderScope(
          order: _cameraOrder,
          child: DartLinksScope(
            links: _dartLinks,
            child: CallerScope(
              caller: _caller,
              child: DisplayScope(
                settings: _display,
                child: manager == null ? app : LocalEngineScope(manager: manager, settings: _settings, child: app),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Above every page while the app tries to reach a lost engine again, so a game or setup page left open says why
/// nothing arrives.
class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!EngineScope.of(context).reconnecting) return child;
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    return Column(
      children: [
        Material(
          color: Color.alphaBlend(colors.warning.withValues(alpha: 0.2), theme.colorScheme.surface),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).engineReconnecting,
                      key: const ValueKey('engine-reconnecting'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}
