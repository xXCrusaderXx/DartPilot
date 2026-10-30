import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine_connection.dart';
import 'game_record.dart';
import 'player_stats.dart';
import 'precision.dart';
import '../theme.dart';

/// Where played games are kept
abstract interface class GameStore {
  Future<List<GameRecord>> load();
  Future<void> add(GameRecord record);

  /// The game being played, kept after every dart so that it survives the app being killed; null when none is
  Future<GameRecord?> loadRunning();
  Future<void> saveRunning(GameRecord? record);
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

  Future<File> get _running async => File('${(await file).parent.path}${Platform.pathSeparator}running_game.json');

  @override
  Future<GameRecord?> loadRunning() async {
    final f = await _running;
    if (!await f.exists()) return null;
    try {
      return GameRecord.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// Writes one after the other: a dart can follow before the previous state is on disk.
  Future<void> _writing = Future.value();

  @override
  Future<void> saveRunning(GameRecord? record) => _writing = _writing.then((_) => _writeRunning(record));

  Future<void> _writeRunning(GameRecord? record) async {
    final f = await _running;
    if (record == null) {
      if (await f.exists()) await f.delete();
      return;
    }
    await f.parent.create(recursive: true);
    // Written aside and renamed, so a kill while writing leaves the previous state, not half a file.
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(jsonEncode(record.toJson()), flush: true);
    await temp.rename(f.path);
  }
}

class MemoryGameStore implements GameStore {
  MemoryGameStore([List<GameRecord>? records]) : records = records ?? [];

  final List<GameRecord> records;

  @override
  Future<List<GameRecord>> load() async => List.of(records);

  @override
  Future<void> add(GameRecord record) async => records.add(record);

  GameRecord? running;

  @override
  Future<GameRecord?> loadRunning() async => running;

  @override
  Future<void> saveRunning(GameRecord? record) async => running = record;
}

/// The player profiles of this device, in the order they were created
abstract interface class ProfileStore {
  Future<List<String>> load();
  Future<void> save(List<String> profiles);

  /// The colours the players chose, as ARGB by the name in lower case
  Future<Map<String, int>> loadColours();
  Future<void> saveColours(Map<String, int> colours);
}

class PrefsProfileStore implements ProfileStore {
  static const _key = 'players.profiles';
  static const _coloursKey = 'players.colours';

  @override
  Future<List<String>> load() async => (await SharedPreferences.getInstance()).getStringList(_key) ?? [];

  @override
  Future<void> save(List<String> profiles) async =>
      (await SharedPreferences.getInstance()).setStringList(_key, profiles);

  /// Kept as "name=argb" entries, which survive any name
  @override
  Future<Map<String, int>> loadColours() async {
    final entries = (await SharedPreferences.getInstance()).getStringList(_coloursKey) ?? [];
    return {
      for (final e in entries)
        if (e.lastIndexOf('=') case final i when i > 0) e.substring(0, i): ?int.tryParse(e.substring(i + 1)),
    };
  }

  @override
  Future<void> saveColours(Map<String, int> colours) async => (await SharedPreferences.getInstance()).setStringList(
    _coloursKey,
    [for (final MapEntry(:key, :value) in colours.entries) '$key=$value'],
  );
}

class MemoryProfileStore implements ProfileStore {
  MemoryProfileStore([List<String>? profiles]) : profiles = profiles ?? [];

  List<String> profiles;

  @override
  Future<List<String>> load() async => List.of(profiles);

  @override
  Future<void> save(List<String> profiles) async => this.profiles = List.of(profiles);

  Map<String, int> colours = {};

  @override
  Future<Map<String, int>> loadColours() async => Map.of(colours);

  @override
  Future<void> saveColours(Map<String, int> colours) async => this.colours = Map.of(colours);
}

/// Why a name cannot become a profile
enum ProfileError { empty, exists }

/// The played games and the player profiles of this device. Every player plays under a profile, so every game counts
/// for someone's statistics.
class Statistics extends ChangeNotifier {
  Statistics(this.store, [ProfileStore? profileStore]) : profileStore = profileStore ?? MemoryProfileStore();

  final GameStore store;
  final ProfileStore profileStore;

  /// Figures per player and period, computed once until the games change
  final Map<(String, DateTime?), PlayerStats> _stats = {};
  final Map<(String, DateTime?), List<TargetPrecision>> _precision = {};

  PlayerStats statsOf(String player, {DateTime? since}) =>
      _stats.putIfAbsent((player, since), () => computePlayerStats(games, player, since: since));

  List<TargetPrecision> precisionOf(String player, {DateTime? since}) =>
      _precision.putIfAbsent((player, since), () => computePlayerPrecision(games, player, since: since));

  @override
  void notifyListeners() {
    _stats.clear();
    _precision.clear();
    super.notifyListeners();
  }

  List<GameRecord> games = [];
  List<String> profiles = [];
  bool loaded = false;

  /// The colours players chose, by the name in lower case
  Map<String, Color> _colours = {};

  /// A profile's colour: the one the player chose, or one of [playerColours] by the profile's place. Guests and bots
  /// have none.
  Color? colourOf(String player) {
    final key = player.toLowerCase();
    final index = profiles.indexWhere((p) => p.toLowerCase() == key);
    if (index < 0) return null;
    return _colours[key] ?? playerColours[index % playerColours.length];
  }

  /// Whether the player chose the colour, rather than having one by their place
  bool hasOwnColour(String player) => _colours.containsKey(player.toLowerCase());

  /// The player's colour, or back to the one by their place when null
  Future<void> setColour(String player, Color? colour) async {
    final key = player.toLowerCase();
    _colours = {..._colours}..remove(key);
    if (colour != null) _colours[key] = colour;
    notifyListeners();
    await profileStore.saveColours({for (final MapEntry(:key, :value) in _colours.entries) key: value.toARGB32()});
  }

  /// A game the app was killed in, to resume or end; null when there is none
  GameRecord? interrupted;

  Future<void> load() async {
    games = await store.load();
    interrupted = await store.loadRunning();
    profiles = await profileStore.load();
    _colours = {for (final MapEntry(:key, :value) in (await profileStore.loadColours()).entries) key: Color(value)};
    // Players of games kept before profiles existed become profiles, so their statistics stay reachable.
    final known = {for (final p in profiles) p.toLowerCase()};
    final missing = [
      for (final p in _playedNames())
        if (known.add(p.toLowerCase())) p,
    ];
    if (missing.isNotEmpty) {
      profiles = [...profiles, ...missing];
      await profileStore.save(profiles);
    }
    loaded = true;
    notifyListeners();
  }

  Iterable<String> _playedNames() sync* {
    for (final g in games) {
      for (var i = 0; i < g.players.length; ++i) {
        if (!isGuestName(g.players[i]) && !g.bots.containsKey(i)) yield g.players[i];
      }
    }
  }

  /// Adds a profile; null when it was added. Names are compared without case, so "anna" and "Anna" are one player.
  Future<ProfileError?> addProfile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return ProfileError.empty;
    if (profiles.any((p) => p.toLowerCase() == trimmed.toLowerCase())) return ProfileError.exists;
    profiles = [...profiles, trimmed];
    notifyListeners();
    await profileStore.save(profiles);
    return null;
  }

  /// Removes a profile; its games stay kept and count again if a profile of the same name is created.
  Future<void> removeProfile(String name) async {
    profiles = [
      for (final p in profiles)
        if (p != name) p,
    ];
    notifyListeners();
    await profileStore.save(profiles);
    if (hasOwnColour(name)) await setColour(name, null);
  }

  /// Keeps the game being played after every dart; null when it ended normally.
  Future<void> keepRunning(GameRecord? record) => store.saveRunning(record);

  /// The interrupted game is played on, or ended: then it counts as the unfinished game it is.
  Future<void> settleInterrupted({required bool resume}) async {
    final game = interrupted;
    if (game == null) return;
    interrupted = null;
    notifyListeners();
    await store.saveRunning(null);
    if (!resume) await record(game);
  }

  /// Keeps a game; games without darts are not worth keeping.
  Future<void> record(GameRecord game) async {
    if (game.throws.isEmpty) return;
    games = [...games, game];
    notifyListeners();
    await store.add(game);
  }

  /// The profiles, most recently played first, then those without games in the order they were created
  List<String> get players {
    final last = <String, DateTime>{};
    for (final g in games) {
      for (final p in g.players) {
        final seen = last[p];
        if (seen == null || g.ended.isAfter(seen)) last[p] = g.ended;
      }
    }
    final played = [
      for (final p in profiles)
        if (last.containsKey(p)) p,
    ]..sort((a, b) => last[b]!.compareTo(last[a]!));
    return [
      ...played,
      for (final p in profiles)
        if (!last.containsKey(p)) p,
    ];
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

  /// The game so far as a record, for its summary at the end
  GameRecord get currentRecord => buildRecord('current', _started, DateTime.now());

  /// A screen that only shows another app's game keeps nothing and shares nothing.
  bool get watching => false;

  EngineConnection? _engine;
  final String _shareId = Statistics.newId();
  int? _sharedSignature;
  bool _shared = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statistics = StatisticsScope.read(context);
    _engine = context.getInheritedWidgetOfExactType<EngineScope>()?.notifier;
  }

  /// Call after every build: when the game changed, keeps it so it survives the app being killed, and shares it with
  /// other displays through the engine (#116).
  void shareGame() {
    if (watching) return;
    final record = buildRecord(_shareId, _started, DateTime.now());
    // Corrections replace a dart without changing the count; the last dart's point tells them apart.
    final signature = Object.hashAll([record.throws.length, for (final t in record.throws) t.point]);
    if (signature == _sharedSignature) return;
    _sharedSignature = signature;
    if (record.throws.isNotEmpty) _statistics?.keepRunning(record);
    final engine = _engine;
    if (engine != null && engine.isConnected) {
      engine.shareGame(record.toJson());
      _shared = true;
    }
  }

  @override
  void dispose() {
    if (!watching && _shared) _engine?.endSharedGame();
    final statistics = _statistics;
    if (statistics != null && !watching) {
      final record = buildRecord(Statistics.newId(), _started, DateTime.now());
      statistics.keepRunning(null);
      // Listeners may not rebuild while the tree is being torn down.
      scheduleMicrotask(() => statistics.record(record));
    }
    super.dispose();
  }
}
