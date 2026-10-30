import 'game_record.dart';
import 'player_stats.dart';

/// What a game is measured by when it is played alone: its points in Shanghai, Bob's 27 and Halve-It, marks per round
/// in Cricket, the hit rate in Around the Clock; higher is better. Null for other modes.
double? soloMeasure(PlayedGame game) => switch (game.record.mode) {
  GameMode.shanghai || GameMode.bobs27 || GameMode.halveIt => game.points?.toDouble(),
  GameMode.cricket => game.marksPerRound,
  GameMode.aroundTheClock => game.hitRate,
  _ => null,
};

/// The best of [history] in games played by the rules of [record]: the same mode, and for Shanghai the same number of
/// rounds. Null when there is none.
double? personalBest(List<PlayedGame> history, GameRecord record) {
  double? best;
  for (final game in history) {
    if (game.record.mode != record.mode) continue;
    if (record.mode == GameMode.shanghai && game.record.settings['rounds'] != record.settings['rounds']) continue;
    final value = soloMeasure(game);
    if (value != null && (best == null || value > best)) best = value;
  }
  return best;
}
