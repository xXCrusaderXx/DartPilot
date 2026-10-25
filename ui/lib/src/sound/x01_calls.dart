import '../games/x01.dart';

/// The caller speaks English whatever the app's language, as callers at darts do; these are speech, not screen text.
const callMatchShot = 'Game shot, and the match!';
const callGameShot = 'Game shot!';
const callBust = 'Bust';
const callNoScore = 'No score';
const callOneEighty = 'One hundred and eighty!';
const callLanguage = 'en';

String callYouRequire(String name, int remaining) => '$name, you require $remaining';

/// What a caller says after a dart of an X01 game (#132): the visit's score when it ends, "game shot" when a leg is
/// won, and what the next player needs when it can be finished. `visitsBefore` and `legBefore` are the game's
/// `visits.length` and `legNumber` before the dart.
List<String> x01Calls(X01Game game, {required int visitsBefore, required int legBefore}) {
  if (game.isFinished) return [callMatchShot];
  if (game.legNumber != legBefore) return [callGameShot];
  if (game.visits.length <= visitsBefore) return const [];
  final ended = game.visits[game.visits.length - 2];
  final calls = [
    ended.isBust
        ? callBust
        : switch (ended.points) {
            0 => callNoScore,
            180 => callOneEighty,
            final points => '$points',
          },
  ];
  final next = game.players[game.current];
  if (game.checkoutSuggestion != null) calls.add(callYouRequire(next.name, next.remaining));
  return calls;
}
