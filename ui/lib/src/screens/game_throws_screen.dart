import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../stats/game_record.dart';
import 'throw_views_screen.dart';

/// Every dart of a played game, visit by visit (#129); a detected dart opens its camera views.
class GameThrowsScreen extends StatelessWidget {
  const GameThrowsScreen({super.key, required this.record});

  final GameRecord record;

  /// The visits of the game: who threw, and the indexes of their darts, at most three
  List<(int player, List<int> darts)> get visits {
    final playerOf = record.replay().playerOf;
    final visits = <(int, List<int>)>[];
    for (var i = 0; i < record.throws.length; ++i) {
      final player = playerOf[i];
      if (visits.isEmpty || visits.last.$1 != player || visits.last.$2.length == 3) visits.add((player, []));
      visits.last.$2.add(i);
    }
    return visits;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameThrowsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (player, darts) in visits)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(record.players[player], style: theme.textTheme.titleSmall),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [for (final i in darts) _DartChip(index: i, dart: record.throws[i])],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DartChip extends StatelessWidget {
  const _DartChip({required this.index, required this.dart});

  final int index;
  final DartThrow dart;

  @override
  Widget build(BuildContext context) {
    final id = dart.engineThrowId;
    return ActionChip(
      key: ValueKey('game-dart-$index'),
      avatar: Icon(id != null ? Icons.videocam : Icons.touch_app, size: 16),
      label: Text(dart.score.label),
      onPressed: id == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ThrowViewsScreen(throwId: id, label: dart.score.label),
              ),
            ),
    );
  }
}
