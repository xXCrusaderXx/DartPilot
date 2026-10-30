// A backup of the player data: the JSON export read back on another device or after a reinstall.
import 'dart:convert';

import 'game_record.dart';

/// What a backup file holds
class Backup {
  const Backup({required this.games, required this.profiles, required this.colours, this.unreadable = 0});

  final List<GameRecord> games;
  final List<String> profiles;

  /// ARGB by the name in lower case
  final Map<String, int> colours;

  /// Games in the file this version cannot read; they are left out of the import.
  final int unreadable;

  /// The backup in [text], the app's JSON export; a FormatException when the text is no such export, so a wrong or
  /// damaged file is refused before anything is changed
  static Backup parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('not JSON');
    }
    if (json is! Map<String, dynamic> || json['games'] is! List) throw const FormatException('not a DartPilot export');
    final games = <GameRecord>[];
    var unreadable = 0;
    for (final entry in json['games'] as List) {
      final record = GameRecord.tryParse(entry);
      if (record == null) {
        unreadable++;
      } else {
        games.add(record);
      }
    }
    // Exports before profiles were part of them name the players only as the keys of their figures.
    final profiles = switch (json['profiles']) {
      final List<dynamic> list => [for (final p in list) ?(p is String ? p : null)],
      _ => switch (json['players']) {
        final Map<String, dynamic> players => players.keys.toList(),
        _ => <String>[],
      },
    };
    final colours = <String, int>{
      if (json['colours'] case final Map<String, dynamic> map)
        for (final MapEntry(:key, :value) in map.entries)
          if (value is int) key.toLowerCase(): value,
    };
    if (games.isEmpty && profiles.isEmpty && unreadable > 0) throw const FormatException('no game can be read');
    return Backup(games: games, profiles: profiles, colours: colours, unreadable: unreadable);
  }
}

/// How many games and profiles an import added
typedef BackupImport = ({int games, int profiles});
