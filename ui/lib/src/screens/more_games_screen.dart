import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../stats/game_record.dart';
import 'killer_screen.dart';
import 'round_game_screen.dart';

/// More games (#118): Shanghai, Bob's 27, Halve-It and Killer
class MoreGamesScreen extends StatelessWidget {
  const MoreGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = [
      (Icons.filter_7, GameMode.shanghai, l10n.modeShanghai, l10n.modeShanghaiDescription),
      (Icons.exposure, GameMode.bobs27, l10n.modeBobs27, l10n.modeBobs27Description),
      (Icons.call_split, GameMode.halveIt, l10n.modeHalveIt, l10n.modeHalveItDescription),
      (Icons.gps_fixed, GameMode.killer, l10n.modeKiller, l10n.modeKillerDescription),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeMoreGames)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (icon, mode, title, description) in games)
                Card(
                  child: ListTile(
                    key: ValueKey('mode-$title'),
                    leading: Icon(icon, size: 32),
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
