import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/prefs_game_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameRecord _game(String id) => GameRecord(
  id: id,
  mode: GameMode.x01,
  started: DateTime(2026, 10, 24, 20),
  ended: DateTime(2026, 10, 24, 21),
  players: const ['Anna'],
  settings: const {'start_score': 101},
  throws: [DartThrow(fieldCentre(Ring.triple, sector: 20), ThrowInput.keypad)],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('games are kept in order and survive a new store', () async {
    await PrefsGameStore().add(_game('a'));
    await PrefsGameStore().add(_game('b'));
    final games = await PrefsGameStore().load();
    expect([for (final g in games) g.id], ['a', 'b']);
    expect(games.first.throws, hasLength(1));
  });

  test('entries this version cannot read are skipped', () async {
    SharedPreferences.setMockInitialValues({
      'games.records': ['not json', '{"mode":"unknown"}'],
    });
    final store = PrefsGameStore();
    await store.add(_game('a'));
    expect([for (final g in await store.load()) g.id], ['a']);
  });

  test('the running game is kept until it is cleared', () async {
    final store = PrefsGameStore();
    expect(await store.loadRunning(), isNull);
    await store.saveRunning(_game('r'));
    expect((await PrefsGameStore().loadRunning())?.id, 'r');
    await store.saveRunning(null);
    expect(await store.loadRunning(), isNull);
  });
}
