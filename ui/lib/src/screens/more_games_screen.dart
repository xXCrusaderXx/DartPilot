import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../stats/game_record.dart';
import '../theme.dart';
import 'killer_screen.dart';
import 'round_game_screen.dart';

/// More games (#118): Shanghai, Bob's 27, Halve-It and Killer
class MoreGamesScreen extends StatelessWidget {
  const MoreGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Each game by what it is about: Shanghai's rounds, Bob's 27 start, the halving, Killer's target
    final games = [
      (const _Mark('1–7'), GameMode.shanghai, l10n.modeShanghai, l10n.modeShanghaiDescription),
      (const _Mark('27'), GameMode.bobs27, l10n.modeBobs27, l10n.modeBobs27Description),
      (const _Mark('½'), GameMode.halveIt, l10n.modeHalveIt, l10n.modeHalveItDescription),
      (const _Mark(null), GameMode.killer, l10n.modeKiller, l10n.modeKillerDescription),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeMoreGames)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (mark, mode, title, description) in games)
                Card(
                  child: ListTile(
                    key: ValueKey('mode-$title'),
                    leading: mark,
                    title: Text(title),
                    subtitle: Text(description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: mode == GameMode.killer ? KillerScreen.setup : RoundGameScreen.setup(mode),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A game's sign in the accent colour, as the home page shows its games: a figure in the score face, or Killer's target
class _Mark extends StatelessWidget {
  const _Mark(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.colorScheme.primary;
    return SizedBox(
      width: 40,
      child: Center(
        child: text == null
            ? Icon(Icons.gps_fixed, size: 32, color: colour)
            : Text(
                text!,
                style: scoreStyle(theme.textTheme.titleLarge)?.copyWith(color: colour, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
