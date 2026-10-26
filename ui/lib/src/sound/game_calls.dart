import '../games/around_the_clock.dart';
import '../games/cricket.dart';
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
