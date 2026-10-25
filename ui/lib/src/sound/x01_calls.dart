import '../../l10n/app_localizations.dart';
import '../games/x01.dart';

/// What a caller says after a dart of an X01 game (#132): the visit's score when it ends, "game shot" when a leg is
/// won, and what the next player needs when it can be finished. `visitsBefore` and `legBefore` are the game's
/// `visits.length` and `legNumber` before the dart.
List<String> x01Calls(AppLocalizations l10n, X01Game game, {required int visitsBefore, required int legBefore}) {
  if (game.isFinished) return [l10n.callMatchShot];
  if (game.legNumber != legBefore) return [l10n.callGameShot];
  if (game.visits.length <= visitsBefore) return const [];
  final ended = game.visits[game.visits.length - 2];
  final calls = [
    ended.isBust
        ? l10n.callBust
        : switch (ended.points) {
            0 => l10n.callNoScore,
            180 => l10n.callOneEighty,
            final points => '$points',
          },
  ];
  final next = game.players[game.current];
  if (game.checkoutSuggestion != null) calls.add(l10n.callYouRequire(next.name, next.remaining));
  return calls;
}
