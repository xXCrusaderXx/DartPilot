import '../games/around_the_clock.dart';
import '../games/cricket.dart';
import '../games/killer.dart';
import '../games/round_games.dart';
import 'x01_calls.dart';

/// What a caller says after a dart of a Cricket game (#132): the marks of a visit when it ends, the match at the end
List<String> cricketCalls(CricketGame game) {
  if (game.isFinished) return [callMatchShot];
  if (game.currentVisit.length < 3) return const [];
  final marks = game.currentVisit.fold(0, (sum, d) => sum + d.marks);
  return [
    switch (marks) {
      0 => callNoScore,
      1 => 'One mark',
      _ => '$marks marks',
    },
  ];
}

/// What a caller says after a dart of an Around the Clock game (#132): when a visit ends, who is next and at what
List<String> aroundTheClockCalls(AroundTheClockGame game) {
  if (game.isFinished) return [callMatchShot];
  if (game.currentVisit.length < 3) return const [];
  final next = game.players[game.current];
  return ['${next.name}, ${game.targetLabel(next.position.clamp(0, game.targetCount - 1))}'];
}

/// What a caller says after a dart of Shanghai, Bob's 27 or Halve-It (#118, #132): what the visit did to the score of
/// `player`, who had `scoreBefore` before the dart, when the visit ends; a player going out; the match at the end.
List<String> roundCalls(RoundGame game, {required int player, required int scoreBefore}) {
  final state = game.players[player];
  final change = state.score - scoreBefore;
  if (game.isFinished) {
    return [if (game is ShanghaiGame && game.winner == player && change > 0) 'Shanghai!', callMatchShot];
  }
  if (game.currentVisit.length < 3) return const [];
  return [
    switch (game) {
      HalveItGame() when change < 0 => 'Halved, ${state.score}',
      Bobs27Game() when change < 0 => 'Minus ${-change}, ${state.score}',
      Bobs27Game() => 'Plus $change, ${state.score}',
      _ when change == 0 => callNoScore,
      _ => '$change',
    },
    if (state.out) '${state.name} is out',
  ];
}

/// What a caller says after a dart of Killer (#118, #132): a new killer, a life taken, a player out, the match.
/// `livesBefore` and `killersBefore` are every player's lives and killer state before the dart.
List<String> killerCalls(KillerGame game, {required List<int> livesBefore, required List<bool> killersBefore}) {
  if (game.isFinished) return [callMatchShot];
  final calls = <String>[];
  for (var i = 0; i < game.players.length; ++i) {
    final p = game.players[i];
    if (p.isKiller && !killersBefore[i]) {
      calls.add('${p.name} is a killer!');
    }
    if (p.lives < livesBefore[i]) {
      calls.add(p.out ? '${p.name} is out' : '${p.name}, ${p.lives} ${p.lives == 1 ? 'life' : 'lives'} left');
    }
  }
  return calls;
}

/// A checkout route as a caller reads it: "Treble 20, treble 19, double 12"
String callRoute(List<String> route) {
  final words = [
    for (final field in route)
      switch (field[0]) {
        'T' => 'treble ${field.substring(1)}',
        'D' => 'double ${field.substring(1)}',
        'S' => field.substring(1),
        _ => field == '50' ? 'bull' : field,
      },
  ];
  final text = words.join(', ');
  return text[0].toUpperCase() + text.substring(1);
}
