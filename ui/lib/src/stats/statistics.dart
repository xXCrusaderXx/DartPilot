import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'game_record.dart';

/// Where played games are kept
abstract interface class GameStore {
  Future<List<GameRecord>> load();
  Future<void> add(GameRecord record);
}

/// One JSON line per game in the app's support directory, appended at the end of every game; lines this version
/// cannot read are kept in the file and skipped.
class FileGameStore implements GameStore {
  FileGameStore([this._file]);

  File? _file;

  Future<File> get file async =>
      _file ??= File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}games.jsonl');

  @override
  Future<List<GameRecord>> load() async {
    final f = await file;
    if (!await f.exists()) return [];
    final records = <GameRecord>[];
    for (final line in await f.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final record = GameRecord.fromJson(jsonDecode(line) as Map<String, dynamic>);
        if (record != null) records.add(record);
      } on FormatException {
        continue;
      }
    }
    return records;
  }

  @override
  Future<void> add(GameRecord record) async {
    final f = await file;
    await f.parent.create(recursive: true);
    await f.writeAsString('${jsonEncode(record.toJson())}\n', mode: FileMode.append, flush: true);
  }
}

class MemoryGameStore implements GameStore {
  MemoryGameStore([List<GameRecord>? records]) : records = records ?? [];

  final List<GameRecord> records;

  @override
  Future<List<GameRecord>> load() async => List.of(records);

  @override
  Future<void> add(GameRecord record) async => records.add(record);
}

/// The played games of this device, for the statistics pages
class Statistics extends ChangeNotifier {
  Statistics(this.store);

  final GameStore store;
  List<GameRecord> games = [];
  bool loaded = false;

  Future<void> load() async {
    games = await store.load();
    loaded = true;
    notifyListeners();
  }

  /// Keeps a game; games without darts are not worth keeping.
  Future<void> record(GameRecord game) async {
    if (game.throws.isEmpty) return;
    games = [...games, game];
    notifyListeners();
    await store.add(game);
  }

  /// Players with a profile, i.e. a name of their own, most recently played first
  List<String> get players {
    final last = <String, DateTime>{};
    for (final g in games) {
      for (final p in g.players) {
        if (isGuestName(p)) continue;
        final seen = last[p];
        if (seen == null || g.ended.isAfter(seen)) last[p] = g.ended;
      }
    }
    return last.keys.toList()..sort((a, b) => last[b]!.compareTo(last[a]!));
  }

  static String newId() =>
      '${DateTime.now().toUtc().toIso8601String()}-${math.Random().nextInt(0x7fffffff).toRadixString(16)}';
}

class StatisticsScope extends InheritedNotifier<Statistics> {
  const StatisticsScope({super.key, required Statistics statistics, required super.child})
    : super(notifier: statistics);

  static Statistics? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StatisticsScope>()?.notifier;

  /// Without rebuilding when the statistics change, for keeping a game
  static Statistics? read(BuildContext context) => context.getInheritedWidgetOfExactType<StatisticsScope>()?.notifier;
}

/// Keeps the game of a game screen when the player leaves it, finished or not, so an undo after the last dart is part
/// of what is kept.
mixin RecordsGame<T extends StatefulWidget> on State<T> {
  Statistics? _statistics;
  final DateTime _started = DateTime.now();

  GameRecord buildRecord(String id, DateTime started, DateTime ended);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statistics = StatisticsScope.read(context);
  }

  @override
  void dispose() {
    final statistics = _statistics;
    if (statistics != null) {
      final record = buildRecord(Statistics.newId(), _started, DateTime.now());
      // Listeners may not rebuild while the tree is being torn down.
      scheduleMicrotask(() => statistics.record(record));
    }
    super.dispose();
  }
}
