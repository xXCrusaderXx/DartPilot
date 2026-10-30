import '../games/around_the_clock.dart';
import '../games/cricket.dart';
import '../games/killer.dart';
import '../games/round_games.dart';
import 'x01_calls.dart';

/// What a caller says after a dart of a Cricket game (#132): the marks of a visit when it ends; at the end who won, or
/// in a solo game the darts it took. "Game shot" belongs to X01 and is not said here.
List<String> cricketCalls(CricketGame game) {
  if (game.isFinished) {
    if (game.players.length == 1) return ['All closed in ${game.players.single.dartsThrown} darts'];
    return ['${game.players[game.winner!].name} wins'];
  }
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

/// What a caller says after a dart of an Around the Clock game (#132): when a visit ends, who is next and at what; at
/// the end who won, or in a solo game the darts it took
List<String> aroundTheClockCalls(AroundTheClockGame game) {
  if (game.isFinished) {
    if (game.players.length == 1) return ['Round the clock in ${game.players.single.dartsThrown} darts'];
    return ['${game.players[game.winner!].name} wins'];
  }
  if (game.currentVisit.length < 3) return const [];
  final next = game.players[game.current];
  return ['${next.name}, ${game.targetLabel(next.position.clamp(0, game.targetCount - 1))}'];
}

/// What a caller says after a dart of Shanghai, Bob's 27 or Halve-It (#118, #132): what the visit did to the score of
/// `player`, who had `scoreBefore` before the dart, when the visit ends, and a player going out. At the end a real
/// Shanghai, then who won or a draw; a solo game ends on its final score.
List<String> roundCalls(RoundGame game, {required int player, required int scoreBefore}) {
  final state = game.players[player];
  final change = state.score - scoreBefore;
  if (game.isFinished && game.wonAtOnce) {
    return ['Shanghai!', if (game.winner != null) '${game.players[game.winner!].name} wins'];
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
    if (game.isFinished)
      if (game.winner != null)
        '${game.players[game.winner!].name} wins'
      else if (game.isDraw)
        "It's a draw"
      else if (!state.out)
        'Final score, ${state.score}',
  ];
}

/// What a caller says after a dart of Killer (#118, #132): a new killer, a life taken, a player out, and who won.
/// `livesBefore` and `killersBefore` are every player's lives and killer state before the dart.
List<String> killerCalls(KillerGame game, {required List<int> livesBefore, required List<bool> killersBefore}) {
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
  if (game.isFinished) calls.add('${game.players[game.winner!].name} wins');
  return calls;
}

/// A checkout route as a caller reads it: "Treble 20, treble 19, double 12"; takes the fields as [suggestCheckout]
/// or [routeText] names them
String callRoute(List<String> route) {
  final words = [
    for (final field in route)
      switch (field[0]) {
        'T' => 'treble ${field.substring(1)}',
        'D' => 'double ${field.substring(1)}',
        'S' => field.substring(1),
        _ => field == '50' || field == 'Bull' ? 'bull' : field,
      },
  ];
  final text = words.join(', ');
  return text[0].toUpperCase() + text.substring(1);
}
