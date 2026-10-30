import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_record.dart';
import 'statistics.dart';

/// The played games in the app's preferences, for the browser, which has no files: one JSON string per game, entries
/// this version cannot read kept and skipped as in [FileGameStore].
class PrefsGameStore implements GameStore {
  static const _gamesKey = 'games.records';
  static const _runningKey = 'games.running';

  @override
  Future<List<GameRecord>> load() async {
    final records = <GameRecord>[];
    for (final entry in (await SharedPreferences.getInstance()).getStringList(_gamesKey) ?? const <String>[]) {
      try {
        final record = GameRecord.tryParse(jsonDecode(entry));
        if (record != null) records.add(record);
      } on FormatException {
        continue;
      }
    }
    return records;
  }

  @override
  Future<void> add(GameRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_gamesKey, [...?prefs.getStringList(_gamesKey), jsonEncode(record.toJson())]);
  }

  @override
  Future<GameRecord?> loadRunning() async {
    final text = (await SharedPreferences.getInstance()).getString(_runningKey);
    if (text == null) return null;
    try {
      return GameRecord.tryParse(jsonDecode(text));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveRunning(GameRecord? record) async {
    final prefs = await SharedPreferences.getInstance();
    if (record == null) {
      await prefs.remove(_runningKey);
    } else {
      await prefs.setString(_runningKey, jsonEncode(record.toJson()));
    }
  }
}
