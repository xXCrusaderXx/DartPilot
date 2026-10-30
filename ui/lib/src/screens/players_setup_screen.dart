import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import 'game_flow.dart';

/// Setup for games that only need the players and a few switches. It starts from the last line-up of the same game.
class PlayersSetupScreen extends StatefulWidget {
  const PlayersSetupScreen({
    super.key,
    required this.title,
    required this.game,
    required this.start,
    this.options = const [],
    this.minPlayers = 1,
    this.rules,
  });

  final String title;

  /// Which game's line-up is kept and restored, such as 'cricket'
  final String game;

  /// The game's rules in a few lines, shown above the players
  final String? rules;

  /// Players the game needs at least, bots included
  final int minPlayers;

  /// Switches shown under the players, with their default values
  final List<(String, bool)> options;

  /// Builds the game screen from the names, the bot level per player index and the option values
  final Widget Function(List<String> names, Map<int, int> bots, List<bool> options) start;

  @override
  State<PlayersSetupScreen> createState() => _PlayersSetupScreenState();
}

class _PlayersSetupScreenState extends State<PlayersSetupScreen> {
  // The start button follows whether anyone is picked.
  late final PlayerSelection _players = PlayerSelection()..addListener(() => setState(() {}));
  late final List<bool> _options = [for (final (_, value) in widget.options) value];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Starts from the last game's line-up and switches; with nothing kept, the only profile is picked already.
  Future<void> _restore() async {
    final last = await LineUp.load(widget.game);
    if (!mounted || !_players.isEmpty) return;
    final profiles = StatisticsScope.read(context)?.players ?? const <String>[];
    if (last != null) {
      if (last.options.length == _options.length) setState(() => _options.setAll(0, last.options));
      final bots = last.botsByName;
      // A profile deleted since then is left out; the others keep their order.
      _players.setAll([
        for (final p in last.players)
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.rules != null) ...[
                Card(
                  key: const ValueKey('game-rules'),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            label: l10n.gameRules,
                            child: Text(widget.rules!, style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              PlayerPicker(selection: _players),
              StarterChoice(selection: _players),
              for (var i = 0; i < widget.options.length; ++i)
                SwitchListTile(
                  title: Text(widget.options[i].$1),
                  value: _options[i],
                  onChanged: (v) => setState(() => _options[i] = v),
                ),
            ],
          ),
        ),
      ),
      // Always in reach, also with a long line-up or on a phone on its side
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                key: const ValueKey('start-game'),
                onPressed: _players.players.length < widget.minPlayers
                    ? null
                    : () async {
                        if (!await confirmBoardEmpty(context) || !context.mounted) return;
                        final lineUp = LineUp(
                          List.of(_players.players),
                          bots: _players.botIndexes,
                          options: List.of(_options),
                        );
                        lineUp.save(widget.game);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => widget.start(lineUp.players, lineUp.bots, lineUp.options),
                          ),
                        );
                      },
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startGame),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
