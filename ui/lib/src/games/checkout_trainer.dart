import 'dart:math' as math;

import '../board/dart_throw.dart';
import '../stats/precision.dart';
import 'dart_game.dart';
import 'x01.dart';

/// How hard the checkouts of a training are
enum CheckoutRange {
  low(2, 40),
  middle(41, 100),
  high(101, 170),

  /// 121: a checkout made moves up to the next score, a missed one is tried again
  ladder(121, 170);

  const CheckoutRange(this.lowest, this.highest);

  final int lowest;
  final int highest;
}

/// The scores to check out, drawn from [seed] so a kept training replays the same; only scores that can be finished
/// with three darts. For the ladder, its first score for every checkout.
List<int> checkoutStarts(int seed, int count, CheckoutRange range) {
  // The ladder sets only where it begins; the trainer moves up from there.
  if (range == CheckoutRange.ladder) return List.filled(count, range.lowest);
  final finishable = [
    for (var n = range.lowest; n <= range.highest; ++n)
      if (suggestCheckout(n, 3) != null) n,
  ];
  final random = math.Random(seed);
  return [for (var i = 0; i < count; ++i) finishable[random.nextInt(finishable.length)]];
}

/// One checkout of the training as it went
class CheckoutAttempt {
  CheckoutAttempt(this.start);

  final int start;
  final List<DartThrow> darts = [];

  /// The field shown to aim at before each dart
  final List<String> aims = [];
  int remaining = 0;
  bool checkedOut = false;
}

/// Checkout trainer (#125): double-out finishes from random scores, each with a set number of darts. Before every dart
/// it names the field to aim at, so every miss is measured against what the player went for. As a [ladder] (121, #118)
/// only the first score is set: each checkout made moves up by one, a missed one is tried again. Pure logic, no UI.
class CheckoutTrainer implements DartGame, AimedGame {
  CheckoutTrainer(this.starts, {this.dartsPerAttempt = 9, this.ladder = false}) : assert(starts.isNotEmpty) {
    _replay();
  }

  /// The scores to check out; as a ladder, the first score and as many entries as checkouts
  final List<int> starts;
  final bool ladder;

  /// 3: one visit per checkout; 9: three visits
  final int dartsPerAttempt;
  final List<DartThrow> _throws = [];
  late List<CheckoutAttempt> attempts;
  late X01Game _leg;

  @override
  List<DartThrow> get throws => List.unmodifiable(_throws);

  /// The checkout at the oche; the last one once the training is over
  CheckoutAttempt get current => attempts.last;

  @override
  bool get isFinished => attempts.length == starts.length && _attemptOver(current);

  @override
  int get dartsInVisit => isFinished ? 0 : _leg.dartsInVisit;

  /// The field to aim at with the next dart
  String get aim => aimField(_leg.players.first.remaining, 3 - _leg.dartsInVisit);

  int get checkouts => attempts.where((a) => a.checkedOut).length;

  /// Checkouts whose darts are all thrown or that were checked out
  int get attemptsDone => attempts.where(_attemptOver).length;

  /// Share of the finished attempts that were checked out
  double get checkoutRate => attemptsDone == 0 ? 0 : checkouts / attemptsDone;

  @override
  PrecisionTarget? targetOf(int index) {
    var i = index;
    for (final attempt in attempts) {
      if (i < attempt.aims.length) return PrecisionTarget.parse(attempt.aims[i]);
      i -= attempt.aims.length;
    }
    return null;
  }

  @override
  void add(DartThrow dart) {
    if (isFinished) return;
    _throws.add(dart);
    _apply(dart);
  }

  @override
  void undo() {
    if (_throws.isEmpty) return;
    _throws.removeLast();
    _replay();
  }

  @override
  void replace(int index, DartThrow dart) {
    _throws[index] = dart;
    _replay();
  }

  bool _attemptOver(CheckoutAttempt a) => a.checkedOut || a.darts.length >= dartsPerAttempt;

  void _startAttempt(int start) {
    attempts.add(CheckoutAttempt(start)..remaining = start);
    _leg = X01Game(X01Settings(players: const ['player'], startScore: start));
  }

  void _replay() {
    attempts = [];
    _startAttempt(starts.first);
    for (final dart in _throws) {
      _apply(dart);
    }
  }

  void _apply(DartThrow dart) {
    final attempt = current;
    attempt.aims.add(aim);
    attempt.darts.add(dart);
    _leg.add(dart);
    attempt.remaining = _leg.players.first.remaining;
    attempt.checkedOut = _leg.isFinished;
    if (_attemptOver(attempt) && attempts.length < starts.length) {
      _startAttempt(
        ladder
            ? (attempt.checkedOut ? math.min(attempt.start + 1, CheckoutRange.ladder.highest) : attempt.start)
            : starts[attempts.length],
      );
    }
  }

  /// The highest score checked out, for the 121 ladder
  int? get bestCheckout => attempts
      .where((a) => a.checkedOut)
      .map((a) => a.start)
      .fold<int?>(null, (best, s) => best == null || s > best ? s : best);
}
