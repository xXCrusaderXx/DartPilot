import '../games/x01.dart';

/// The caller speaks English whatever the app's language, as callers at darts do; these are speech, not screen text.
const callMatchShot = 'Game shot, and the match!';
const callNoScore = 'No score';

/// A bust scores nothing, and a caller says so in those words
const callBust = callNoScore;
const callOneEighty = 'One hundred and eighty!';
const callNineDarter = 'Nine-darter!';

/// A finish made in the checkout trainer, where no leg or match is won
const callCheckedOut = 'Checked out';
const callLanguage = 'en';

const _ordinals = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth', 'tenth'];

/// "Game shot, and the first leg!" for the leg `leg` (from 1) just won
String callLegShot(int leg) =>
    leg <= _ordinals.length ? 'Game shot, and the ${_ordinals[leg - 1]} leg!' : 'Game shot, and leg $leg!';

String callYouRequire(String name, int remaining) => '${spokenName(name)}, you require $remaining';

/// A player's name as the caller says it: a bot's "Bot · Strong" without the separator, which a voice would read out
String spokenName(String name) => name.replaceAll(' · ', ' ');

/// What a caller says after a dart of an X01 game (#132): the visit's score when it ends, "game shot" when a leg is
/// won, and what the next player needs when it can be finished. `visitsBefore` and `legBefore` are the game's
/// `visits.length` and `legNumber` before the dart.
List<String> x01Calls(X01Game game, {required int visitsBefore, required int legBefore}) {
  if (game.isFinished || game.legNumber != legBefore) {
    final checkout = game.visits.lastWhere((v) => v.isCheckout);
    return [game.isFinished ? callMatchShot : callLegShot(legBefore), if (game.isNineDarter(checkout)) callNineDarter];
  }
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
