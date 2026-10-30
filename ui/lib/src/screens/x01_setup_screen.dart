import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../games/x01.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import 'x01_screen.dart';

/// The line-up and options of the last X01 game started on this device: the next setup starts from them, and Home
/// offers them as a quick start.
class LastX01 {
  const LastX01(this.settings, this.bots);

  final X01Settings settings;

  /// Bot level per player index
  final Map<int, int> bots;

  static const _key = 'x01.last';

  /// Counts up whenever a line-up is saved, for those that show it
  static final ValueNotifier<int> saved = ValueNotifier(0);

  /// Bot names by their level, as the setup keeps them
  Map<String, int> get botsByName => {for (final e in bots.entries) settings.players[e.key]: e.value};

  /// Whether every person in the line-up still has a profile among [profiles]
  bool playableWith(List<String> profiles) => [
    for (var i = 0; i < settings.players.length; ++i)
      if (!bots.containsKey(i)) settings.players[i],
  ].every(profiles.contains);

  static Future<LastX01?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_key);
      if (text == null) return null;
      final json = jsonDecode(text) as Map<String, dynamic>;
      final players = [for (final p in json['players'] as List<dynamic>) p as String];
      if (players.isEmpty) return null;
      return LastX01(
        X01Settings(
          players: players,
          startScore: json['start'] as int? ?? 501,
          doubleIn: json['double_in'] as bool? ?? false,
          doubleOut: json['double_out'] as bool? ?? true,
          legsToWin: json['legs'] as int? ?? 1,
        ),
        {for (final e in (json['bots'] as Map<String, dynamic>? ?? const {}).entries) int.parse(e.key): e.value as int},
      );
    } catch (_) {
      // Nothing kept, or kept by a version that wrote it differently: the setup starts empty.
      return null;
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'players': settings.players,
          'start': settings.startScore,
          'double_in': settings.doubleIn,
          'double_out': settings.doubleOut,
          'legs': settings.legsToWin,
          'bots': {for (final e in bots.entries) '${e.key}': e.value},
        }),
      );
      ++saved.value;
    } catch (_) {
      // Without storage the game is played all the same; only the next setup starts empty.
    }
  }
}

class X01SetupScreen extends StatefulWidget {
  const X01SetupScreen({super.key});

  @override
  State<X01SetupScreen> createState() => _X01SetupScreenState();
}

class _X01SetupScreenState extends State<X01SetupScreen> {
  // The start button follows whether anyone is picked.
  late final PlayerSelection _players = PlayerSelection()..addListener(() => setState(() {}));
  int _startScore = 501;
  bool _doubleIn = false;
  bool _doubleOut = true;
  int _legsToWin = 1;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Starts from the last game's line-up and options; with nothing kept, the only profile is picked already.
  Future<void> _restore() async {
    final last = await LastX01.load();
    if (!mounted || !_players.isEmpty) return;
    final profiles = StatisticsScope.read(context)?.players ?? const <String>[];
    if (last != null) {
      final s = last.settings;
      setState(() {
        _startScore = s.startScore;
        _doubleIn = s.doubleIn;
        _doubleOut = s.doubleOut;
        _legsToWin = s.legsToWin;
      });
      final bots = last.botsByName;
      // A profile deleted since then is left out; the others keep their order.
      _players.setAll([
        for (final p in s.players)
          if (bots.containsKey(p) || profiles.contains(p)) p,
      ], bots);
    } else if (profiles.length == 1) {
      _players.toggle(profiles.single);
    }
  }

  @override
  void dispose() {
    _players.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await confirmBoardEmpty(context) || !mounted) return;
    final settings = X01Settings(
      players: List.of(_players.players),
      startScore: _startScore,
      doubleIn: _doubleIn,
      doubleOut: _doubleOut,
      legsToWin: _legsToWin,
    );
    final bots = _players.botIndexes;
    LastX01(settings, bots).save();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => X01Screen(settings: settings, bots: bots),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final players = _players.players;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.x01Setup)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PlayerPicker(selection: _players),
              if (players.length > 1) ...[
                const SizedBox(height: 16),
                Text(l10n.x01ThrowsFirst, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in players)
                      ChoiceChip(
                        key: ValueKey('first-$name'),
                        label: Text(name),
                        selected: name == players.first,
                        onSelected: (_) => _players.startWith(name),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(l10n.startScore, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final s in [301, 501, 701]) ButtonSegment(value: s, label: Text('$s')),
                ],
                selected: {_startScore},
                onSelectionChanged: (s) => setState(() => _startScore = s.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(l10n.doubleIn),
                value: _doubleIn,
                onChanged: (v) => setState(() => _doubleIn = v),
              ),
              SwitchListTile(
                title: Text(l10n.doubleOut),
                value: _doubleOut,
                onChanged: (v) => setState(() => _doubleOut = v),
              ),
              ListTile(
                title: Text(l10n.legsToWin),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _legsToWin > 1 ? () => setState(() => _legsToWin--) : null,
                      tooltip: l10n.fewerLegs,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_legsToWin', key: const ValueKey('legs-to-win'), style: theme.textTheme.titleLarge),
                    IconButton(
                      // First to 11 is already a long evening
                      onPressed: _legsToWin < 11 ? () => setState(() => _legsToWin++) : null,
                      tooltip: l10n.moreLegs,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Always in reach, also on a phone on its side where the options fill the screen
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_players.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.pickPlayerToStart,
                        key: const ValueKey('start-needs-player'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('start-game'),
                    onPressed: _players.isEmpty ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.startGame),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
