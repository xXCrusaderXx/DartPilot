import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup.dart';
import 'game_record.dart';
import 'player_stats.dart';

/// Every dart of `games` as CSV, one line per dart: which game, which player, the field, and the board point in mm
/// with the engine's throw id where there is one (#117)
String dartsCsv(List<GameRecord> games) {
  final out = StringBuffer('game_id,mode,ended_utc,player,dart,label,ring,sector,points,x_mm,y_mm,input,throw_id\n');
  String field(Object? v) {
    final text = '${v ?? ''}';
    return text.contains(RegExp('[",\n]')) ? '"${text.replaceAll('"', '""')}"' : text;
  }

  for (final record in games) {
    final (:game, :playerOf) = record.replay();
    final darts = <int, int>{};
    for (var i = 0; i < record.throws.length; ++i) {
      final t = record.throws[i];
      final player = i < playerOf.length ? playerOf[i] : -1;
      final number = darts[player] = (darts[player] ?? 0) + 1;
      out.writeln(
        [
          record.id,
          record.mode.name,
          record.ended.toUtc().toIso8601String(),
          player >= 0 && player < record.players.length ? record.players[player] : '',
          number,
          t.score.label,
          t.score.ring.name,
          t.score.sector,
          t.score.points,
          t.point.xMm.toStringAsFixed(2),
          t.point.yMm.toStringAsFixed(2),
          t.input.name,
          t.engineThrowId,
        ].map(field).join(','),
      );
    }
  }
  return out.toString();
}

/// The games as the app stores them, the profiles with their chosen colours (ARGB by the name in lower case), and
/// each player's figures over the games, as JSON: also the backup that [Backup.parse] reads back
String gamesJson(List<GameRecord> games, List<String> players, {Map<String, int> colours = const {}, DateTime? now}) {
  Map<String, Object?> figures(PlayerStats s) => {
    'games': s.games,
    'matches': s.matches,
    'games_won': s.gamesWon,
    'trainings': s.trainings,
    'darts': s.darts,
    'training_darts': s.trainingDarts,
    'three_dart_average': s.threeDartAverage,
    'first_9_average': s.first9Average,
    'legs': s.legs,
    'match_legs': s.matchLegs,
    'legs_won': s.legsWon,
    'best_leg_darts': {for (final e in s.bestLegByStart.entries) '${e.key}': e.value},
    'checkout_rate': s.checkoutRate,
    'highest_finish': s.highestFinish,
    'highest_visit': s.highestVisit,
    'visits_100': s.visits100,
    'visits_140': s.visits140,
    'visits_180': s.visits180,
    'marks_per_round': s.marksPerRound,
    'clock_hit_rate': s.clockHitRate,
    'fields': s.fields,
  };
  return const JsonEncoder.withIndent('  ').convert({
    'format': 'dartpilot-backup',
    'version': 1,
    'exported_utc': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'profiles': players,
    'colours': colours,
    'players': {for (final p in players) p: figures(computePlayerStats(games, p))},
    'games': [for (final g in games) g.toJson()],
  });
}

/// Where exports go: the downloads folder on desktops, the app's folder on shared storage on Android, the documents
/// folder elsewhere
Future<Directory> exportDirectory() async {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  }
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external != null) return external;
  }
  return getApplicationDocumentsDirectory();
}

/// Writes `content` as `name` into the export folder and returns the file
Future<File> writeExport(String name, String content) async {
  final dir = await exportDirectory();
  await dir.create(recursive: true);
  return File('${dir.path}${Platform.pathSeparator}$name').writeAsString(content);
}
