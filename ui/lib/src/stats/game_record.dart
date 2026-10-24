// A played game as it is kept for the statistics (#117): the settings and every dart as a board point, so every
// figure is computed by replaying the game with the same rules as at the oche, also figures added later.
import '../board/dart_throw.dart';
import '../games/around_the_clock.dart';
import '../games/cricket.dart';
import '../games/x01.dart';

enum GameMode { x01, cricket, aroundTheClock }

class GameRecord {
  GameRecord({
    required this.id,
    required this.mode,
    required this.started,
    required this.ended,
    required this.players,
    required this.throws,
    this.settings = const {},
  });

  final String id;
  final GameMode mode;
  final DateTime started;
  final DateTime ended;
  final List<String> players;

  /// Mode settings: X01 start score, double in/out, legs to win; Around the Clock: end with the bull
  final Map<String, Object?> settings;
  final List<DartThrow> throws;

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
        final game = CricketGame(players);
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
    }
  }

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
    'throws': [
      for (final t in throws)
        {
          'x_mm': t.point.xMm,
          'y_mm': t.point.yMm,
          'input': t.input.name,
          if (t.engineThrowId != null) 'throw_id': t.engineThrowId,
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
      throws: [
        for (final t in json['throws'] as List<dynamic>)
          DartThrow(
            BoardPoint(((t as Map)['x_mm'] as num).toDouble(), (t['y_mm'] as num).toDouble()),
            ThrowInput.values.where((i) => i.name == t['input']).firstOrNull ?? ThrowInput.keypad,
            engineThrowId: t['throw_id'] as String?,
          ),
      ],
    );
  }
}

/// Default names ("Player 2", "Spieler 2") belong to guests, who get no statistics.
bool isGuestName(String name) => RegExp(r'^(Player|Spieler) \d+$').hasMatch(name);
