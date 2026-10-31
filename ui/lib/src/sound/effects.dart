import '../board/dart_throw.dart';
import '../games/checkout_trainer.dart';
import '../games/doubles.dart';
import '../games/x01.dart';

/// The app's few sound effects (tools/dartpilot_tools/sounds.py makes them): one short sound per dart, a few for what
/// a dart decided, and a tick when the player has to look at the screen. No music, no crowd.
enum Effect {
  /// A dart in the board: a soft low thud
  dart('dart'),

  /// A dart outside the scoring area: the same thud, duller and quieter
  miss('miss'),

  /// Two muted notes falling
  bust('bust'),

  /// The end of a visit, only when the caller does not speak
  visit('visit'),

  /// The end of a visit of 100 or more, only when the caller does not speak
  visitHigh('visit_high'),

  /// A 180, only when the caller does not speak
  oneEighty('one_eighty'),

  /// A leg won: a short rising triad
  leg('leg'),

  /// The match or game won: the triad a little longer
  match('match'),

  /// The engine asks the player to confirm a dart, or to say what became of missing darts
  attention('attention');

  const Effect(this.file);

  final String file;

  String get asset => 'assets/sounds/$file.wav';

  /// The sound of a dart itself, which a bot's darts play quieter
  bool get perDart => this == dart || this == miss;

  /// Sounds the caller says in words; with the caller on, the dart's own sound plays instead.
  bool get saidByCaller => this == visit || this == visitHigh || this == oneEighty;

  /// What a hand on a phone feels more strongly
  bool get strong => this == bust || this == leg || this == match;
}

/// The sound of `dart` on its own
Effect dartEffect(DartThrow dart) => dart.score.multiplier == 0 ? Effect.miss : Effect.dart;

/// The sound after a dart of an X01 game: the match, a leg, a bust, a 180 or the end of a visit, else the dart's own.
/// `visitsBefore` and `legBefore` are the game's `visits.length` and `legNumber` before the dart.
Effect x01Effect(X01Game game, DartThrow dart, {required int visitsBefore, required int legBefore}) {
  if (game.isFinished) return Effect.match;
  if (game.legNumber != legBefore) return Effect.leg;
  if (game.visits.length <= visitsBefore) return dartEffect(dart);
  final ended = game.visits[game.visits.length - 2];
  if (ended.isBust) return Effect.bust;
  if (ended.points == 180) return Effect.oneEighty;
  return ended.points >= 100 ? Effect.visitHigh : Effect.visit;
}

/// The sound after a dart of any other game: `finished` when it ended the game, `visitEnded` when it ended a visit.
/// A training session that ends sounds like a leg won: there is nobody it was won against.
Effect gameEffect(DartThrow dart, {required bool finished, bool visitEnded = false, bool training = false}) {
  if (finished) return training ? Effect.leg : Effect.match;
  return visitEnded ? Effect.visit : dartEffect(dart);
}

/// The sound after a dart of the checkout trainer or the 121 ladder: a checkout made sounds like a leg won and a bust
/// like a bust, so the player at the board hears what the dart did. `attemptsBefore` and `bustsBefore` are the
/// trainer's attempts and the bust visits of its current attempt before the dart.
Effect checkoutTrainerEffect(
  CheckoutTrainer game,
  DartThrow dart, {
  required int attemptsBefore,
  required int bustsBefore,
}) {
  final attempt = game.attempts[attemptsBefore - 1];
  if (attempt.checkedOut) return Effect.leg;
  if (attempt.leg.visits.where((v) => v.isBust).length > bustsBefore) return Effect.bust;
  return gameEffect(dart, finished: game.isFinished, training: true);
}

/// The sound after a dart of doubles practice: a double hit gets the short sound of a visit, a miss the dart's own
Effect doublesEffect(DoublesGame game, DartThrow dart) {
  if (game.isFinished) return Effect.leg;
  return game.targetOf(game.throws.length - 1).isHit(dart.score) ? Effect.visit : dartEffect(dart);
}
