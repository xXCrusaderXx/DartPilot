import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/board_check.dart';
import '../widgets/player_names.dart';

/// Setup for games that only need the players and a few switches.
class PlayersSetupScreen extends StatefulWidget {
  const PlayersSetupScreen({super.key, required this.title, required this.start, this.options = const []});

  final String title;

  /// Switches shown under the players, with their default values
  final List<(String, bool)> options;

  /// Builds the game screen from the names and the option values
  final Widget Function(List<String> names, List<bool> options) start;

  @override
  State<PlayersSetupScreen> createState() => _PlayersSetupScreenState();
}

class _PlayersSetupScreenState extends State<PlayersSetupScreen> {
  final PlayerNamesController _players = PlayerNamesController();
  late final List<bool> _options = [for (final (_, value) in widget.options) value];

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
              PlayerNamesEditor(controller: _players),
              for (var i = 0; i < widget.options.length; ++i)
                SwitchListTile(
                  title: Text(widget.options[i].$1),
                  value: _options[i],
                  onChanged: (v) => setState(() => _options[i] = v),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  if (!await confirmBoardEmpty(context) || !context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => widget.start(_players.names(l10n), List.of(_options))),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
