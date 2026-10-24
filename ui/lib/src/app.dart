import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'engine/engine_connection.dart';
import 'screens/home_screen.dart';

class DartPilotApp extends StatefulWidget {
  const DartPilotApp({super.key, this.locale, this.engine});

  /// Fixed locale for tests; the system language otherwise
  final Locale? locale;

  /// Engine connection for tests; the app creates its own otherwise
  final EngineConnection? engine;

  @override
  State<DartPilotApp> createState() => _DartPilotAppState();
}

class _DartPilotAppState extends State<DartPilotApp> {
  late final EngineConnection _engine = widget.engine ?? EngineConnection();

  @override
  void dispose() {
    if (widget.engine == null) _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EngineScope(
      connection: _engine,
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        locale: widget.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E8F4E), brightness: Brightness.dark),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
