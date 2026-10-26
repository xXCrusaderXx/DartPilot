// A played game as it is kept for the statistics (#117): the settings and every dart as a board point, so every
// figure is computed by replaying the game with the same rules as at the oche, also figures added later.
import '../board/dart_throw.dart';
import '../games/around_the_clock.dart';
import '../games/checkout_trainer.dart';
import '../games/cricket.dart';
import '../games/dart_game.dart';
import '../games/doubles.dart';
import '../games/grouping.dart';
import '../games/killer.dart';
import '../games/round_games.dart';
import '../games/x01.dart';
import 'precision.dart';

enum GameMode { x01, cricket, aroundTheClock, grouping, doubles, checkout, shanghai, bobs27, halveIt, killer }

class GameRecord {
  GameRecord({
    required this.id,
    required this.mode,
    required this.started,
    required this.ended,
    required this.players,
    required this.throws,
    this.settings = const {},
    this.bots = const {},
  });

  final String id;
  final GameMode mode;
  final DateTime started;
  final DateTime ended;
  final List<String> players;

  /// Mode settings: X01 start score, double in/out, legs to win; Cricket: cut-throat; Around the Clock: end with the bull; grouping: the
  /// target and the number of darts; doubles practice: the doubles in order and the darts at each; checkout trainer:
  /// the scores to check out, the darts for each and whether it is the 121 ladder; Shanghai: the number of rounds; Killer: each player's number and the lives
  final Map<String, Object?> settings;
  final List<DartThrow> throws;

  /// Bot level per player index; bots have no profile and no statistics
  final Map<int, int> bots;

  /// Replays the game: its final state, and for every dart the player who threw it
  ({Object game, List<int> playerOf}) replay() {
    final playerOf = <int>[];
    switch (mode) {
      case GameMode.x01:
        final game = X01Game(x01Settings);
        for (final t in throws) {
          playerOf.add(game.current);
          game.add(t);
        }
        return (game: game, playerOf: playerOf);
      case GameMode.cricket:
        final game = CricketGame(players, cutThroat: settings['cut_throat'] == true);
        for (final t in throws) {
          playerOf.add(game.current);
          game.add(t);
        }
        return (game: game, playerOf: playerOf);
      case GameMode.aroundTheClock:
        final game = AroundTheClockGame(players, endWithBull: settings['end_with_bull'] == true);
        for (final t in throws) {
          playerOf.add(game.current);
          game.add(t);
        }
        return (game: game, playerOf: playerOf);
      case GameMode.grouping:
        return (game: replayed(groupingGame, throws), playerOf: List.filled(throws.length, 0));
      case GameMode.doubles:
        return (game: replayed(doublesGame, throws), playerOf: List.filled(throws.length, 0));
      case GameMode.checkout:
        return (game: replayed(checkoutTrainer, throws), playerOf: List.filled(throws.length, 0));
      case GameMode.killer:
        final game = killerGame;
        for (final t in throws) {
          playerOf.add(game.current);
          game.add(t);
        }
        return (game: game, playerOf: playerOf);
      case GameMode.shanghai || GameMode.bobs27 || GameMode.halveIt:
        final game = roundGame;
        for (final t in throws) {
          playerOf.add(game.current);
          game.add(t);
        }
        return (game: game, playerOf: playerOf);
    }
  }

  /// The empty Killer game of this record's numbers and lives
  KillerGame get killerGame {
    final numbers = [for (final n in settings['numbers'] as List? ?? const []) (n as num).toInt()];
    return KillerGame(
      players,
      numbers.length == players.length ? numbers : killerNumbers(0, players.length),
      lives: settings['lives'] as int? ?? 3,
    );
  }

  /// The empty game of rounds of this record's mode and settings
  RoundGame get roundGame => switch (mode) {
    GameMode.bobs27 => Bobs27Game(players),
    GameMode.halveIt => HalveItGame(players),
    _ => ShanghaiGame(players, rounds: settings['rounds'] as int? ?? 7),
  };

  /// The empty doubles practice of this record's settings
  DoublesGame get doublesGame {
    final targets = [
      for (final label in settings['targets'] as List? ?? const []) ?PrecisionTarget.parse(label as String),
    ];
    return DoublesGame(
      targets.isEmpty ? allDoubles : targets,
      dartsPerTarget: settings['darts_per_target'] as int? ?? 3,
    );
  }

  /// The empty checkout trainer of this record's settings
  CheckoutTrainer get checkoutTrainer {
    final starts = [for (final s in settings['starts'] as List? ?? const []) (s as num).toInt()];
    return CheckoutTrainer(
      starts.isEmpty ? const [40] : starts,
      dartsPerAttempt: settings['darts'] as int? ?? 9,
      ladder: settings['ladder'] == true,
    );
  }

  /// The empty grouping game of this record's settings
  GroupingGame get groupingGame => GroupingGame(groupingTarget, dartCount: settings['darts'] as int? ?? 9);

  PrecisionTarget get groupingTarget =>
      PrecisionTarget.parse(settings['target'] as String? ?? '') ?? trainingTargets.first;

  X01Settings get x01Settings => X01Settings(
    players: players,
    startScore: settings['start_score'] as int? ?? 501,
    doubleIn: settings['double_in'] == true,
    doubleOut: settings['double_out'] != false,
    legsToWin: settings['legs_to_win'] as int? ?? 1,
  );

  static Map<String, Object?> settingsOfX01(X01Settings s) => {
    'start_score': s.startScore,
    'double_in': s.doubleIn,
    'double_out': s.doubleOut,
    'legs_to_win': s.legsToWin,
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'mode': mode.name,
    'started': started.toUtc().toIso8601String(),
    'ended': ended.toUtc().toIso8601String(),
    'players': players,
    'settings': settings,
    if (bots.isNotEmpty) 'bots': {for (final e in bots.entries) '${e.key}': e.value},
    'throws': [
      for (final t in throws)
        {
          'x_mm': t.point.xMm,
          'y_mm': t.point.yMm,
          'input': t.input.name,
          if (t.engineThrowId != null) 'throw_id': t.engineThrowId,
          if (t.confidence != null) 'confidence': t.confidence,
        },
    ],
  };

  /// Null for a record this version cannot read, e.g. a mode added later
  static GameRecord? fromJson(Map<String, dynamic> json) {
    final mode = GameMode.values.where((m) => m.name == json['mode']).firstOrNull;
    if (mode == null) return null;
    return GameRecord(
      id: json['id'] as String,
      mode: mode,
      started: DateTime.parse(json['started'] as String).toLocal(),
      ended: DateTime.parse(json['ended'] as String).toLocal(),
      players: [for (final p in json['players'] as List<dynamic>) p as String],
      settings: Map<String, Object?>.from(json['settings'] as Map? ?? const {}),
      bots: {
        for (final e in (json['bots'] as Map? ?? const {}).entries)
          int.parse(e.key as String): (e.value as num).toInt(),
      },
      throws: [
        for (final t in json['throws'] as List<dynamic>)
          DartThrow(
            BoardPoint(((t as Map)['x_mm'] as num).toDouble(), (t['y_mm'] as num).toDouble()),
            ThrowInput.values.where((i) => i.name == t['input']).firstOrNull ?? ThrowInput.keypad,
            engineThrowId: t['throw_id'] as String?,
            confidence: (t['confidence'] as num?)?.toDouble(),
          ),
      ],
    );
  }
}

/// Default names ("Player 2", "Spieler 2") belong to guests, who get no statistics.
bool isGuestName(String name) => RegExp(r'^(Player|Spieler) \d+$').hasMatch(name);
