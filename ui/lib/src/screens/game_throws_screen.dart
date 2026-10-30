import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/checkout_trainer.dart';
import '../games/x01.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../theme.dart';
import 'throw_views_screen.dart';
import '../board/score_text.dart';

/// Every dart of a played game, visit by visit (#129); a detected dart opens its camera views. A kept game can be
/// deleted here.
class GameThrowsScreen extends StatelessWidget {
  const GameThrowsScreen({super.key, required this.record, this.title});

  final GameRecord record;

  /// The game and its figure, as the history names it
  final String? title;

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final statistics = StatisticsScope.read(context);
    if (statistics == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteGame),
        content: Text(l10n.deleteGameText),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            key: const ValueKey('delete-game-confirm'),
            style: destructiveButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await statistics.removeGame(record.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.gameDeleted)));
  }

  /// The visits of the game: who threw, the indexes of their darts, and in X01 and the checkout trainer the visit's
  /// score and what was left after it. These games end a visit early on a bust or a checkout, so their visits come from
  /// the replayed game; the others have three darts a visit.
  List<ThrowsVisit> get visits {
    final (:game, :playerOf) = record.replay();
    final legs = switch (game) {
      X01Game() => [game],
      CheckoutTrainer() => [for (final a in game.attempts) a.leg],
      _ => null,
    };
    final visits = <ThrowsVisit>[];
    if (legs != null) {
      var next = 0;
      for (final leg in legs) {
        for (final v in leg.visits) {
          if (v.darts.isEmpty) continue;
          final left = v.isBust ? v.startRemaining : v.startRemaining - v.points;
          visits.add(
            ThrowsVisit(v.player, [for (var i = 0; i < v.darts.length; ++i) next + i], v.points, left, v.isBust),
          );
          next += v.darts.length;
        }
      }
      return visits;
    }
    for (var i = 0; i < record.throws.length; ++i) {
      final player = playerOf[i];
      if (visits.isEmpty || visits.last.player != player || visits.last.darts.length == 3) {
        visits.add(ThrowsVisit(player, []));
      }
      visits.last.darts.add(i);
    }
    return visits;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gameThrowsTitle),
        actions: [
          if (StatisticsScope.read(context)?.games.any((g) => g.id == record.id) ?? false)
            IconButton(
              key: const ValueKey('delete-game'),
              tooltip: l10n.deleteGame,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (title != null) ...[
                Text(title!, style: theme.textTheme.titleMedium),
                Text(
                  [
                    DateFormat.yMMMd(l10n.localeName).add_Hm().format(record.ended),
                    record.players.join(', '),
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              for (final (n, visit) in visits.indexed)
                ListTile(
                  key: ValueKey('game-visit-$n'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    [
                      // Solo, the name would only repeat on every line.
                      if (record.players.length > 1) record.players[visit.player] else '${l10n.visit} ${n + 1}',
                      if (visit.left != null) l10n.checkoutLeft(visit.left!),
                    ].join('  ·  '),
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [for (final i in visit.darts) _DartChip(index: i, dart: record.throws[i])],
                  ),
                  trailing: visit.points == null
                      ? null
                      : Text(
                          visit.bust ? l10n.bust : '${visit.points}',
                          key: ValueKey('game-visit-points-$n'),
                          style: visit.bust
                              ? theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)
                              : theme.textTheme.titleLarge,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One visit of a played game
class ThrowsVisit {
  ThrowsVisit(this.player, this.darts, [this.points, this.left, this.bust = false]);

  final int player;

  /// Indexes of the visit's darts in the game's throws
  final List<int> darts;

  /// The visit's score and what was left after it, in games that count down
  final int? points;
  final int? left;
  final bool bust;
}

class _DartChip extends StatelessWidget {
  const _DartChip({required this.index, required this.dart});

  final int index;
  final DartThrow dart;

  @override
  Widget build(BuildContext context) {
    final id = dart.engineThrowId;
    final label = dart.score.text(AppLocalizations.of(context));
    // Only a detected dart has camera views to open; an entered one is a plain chip, not a disabled button.
    if (id == null) {
      return Chip(key: ValueKey('game-dart-$index'), avatar: const Icon(Icons.touch_app, size: 16), label: Text(label));
    }
    return ActionChip(
      key: ValueKey('game-dart-$index'),
      avatar: const Icon(Icons.videocam, size: 16),
      label: Text(label),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ThrowViewsScreen(throwId: id, label: label),
        ),
      ),
    );
  }
}
