import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine_connection.dart';
import '../games/dart_game.dart';

/// What every game screen does around its game the same way: a visit that ended stays on show for a moment, so a
/// bot's darts or a player's own are seen before the next player's.
mixin HoldsVisits<T extends StatefulWidget> on State<T> {
  /// How long a visit that ended stays on the panel when no takeout holds it, unless the next dart comes first
  static const Duration holdTime = Duration(milliseconds: 1500);

  DartGame get heldGame;

  /// The visit that ended stays on show while the game has this many darts
  int? _heldAt;
  Timer? _holdTimer;

  /// Whether the visit that just ended is still on show: an undo or the next dart ends that
  bool get holding =>
      _heldAt == heldGame.throws.length &&
      !heldGame.isFinished &&
      heldGame.dartsInVisit == 0 &&
      heldGame.throws.isNotEmpty;

  /// Call right after a dart was added: when it ended a visit thrown by a bot, or without an engine whose takeout
  /// would hold it, that visit stays on show for [holdTime].
  void holdEndedVisit({required bool bot}) {
    final game = heldGame;
    if (game.isFinished || game.dartsInVisit != 0 || game.throws.isEmpty) return;
    if (!bot && EngineScope.read(context).isConnected) return;
    _holdTimer?.cancel();
    _heldAt = game.throws.length;
    _holdTimer = Timer(holdTime, () {
      if (mounted) setState(() => _heldAt = null);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }
}

/// The players, bots and switches of the last game of a kind started on this device: its setup starts from them, and
/// a rematch plays them again with the next player first.
class LineUp {
  const LineUp(this.players, {this.bots = const {}, this.options = const []});

  final List<String> players;

  /// Bot level per player index
  final Map<int, int> bots;

  /// The setup's switches, in the order the setup shows them
  final List<bool> options;

  /// Counts up whenever a line-up is saved, for those that show it
  static final ValueNotifier<int> saved = ValueNotifier(0);

  /// The same players with the one after the first beginning, as players take turns to start
  LineUp get rotated {
    final n = players.length;
    return LineUp(
      [for (var i = 0; i < n; ++i) players[(i + 1) % n]],
      bots: {for (final e in bots.entries) (e.key - 1 + n) % n: e.value},
      options: options,
    );
  }

  /// The line-up of a rematch of [game]: [rotated], and kept as the game's last line-up
  LineUp rematch(String game) {
    final next = rotated;
    next.save(game);
    return next;
  }

  /// Bot levels by name, as the setup keeps them
  Map<String, int> get botsByName => {for (final e in bots.entries) players[e.key]: e.value};

  static String _key(String game) => 'lineup.$game';

  /// The line-up last kept for [game], or null when there is none
  static Future<LineUp?> load(String game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_key(game));
      if (text == null) return null;
      final json = jsonDecode(text) as Map<String, dynamic>;
      final players = [for (final p in json['players'] as List<dynamic>) p as String];
      if (players.isEmpty) return null;
      return LineUp(
        players,
        bots: {
          for (final e in (json['bots'] as Map<String, dynamic>? ?? const {}).entries) int.parse(e.key): e.value as int,
        },
        options: [for (final o in json['options'] as List<dynamic>? ?? const []) o as bool],
      );
    } catch (_) {
      // Nothing kept, or kept by a version that wrote it differently: the setup starts empty.
      return null;
    }
  }

  Future<void> save(String game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(game),
        jsonEncode({
          'players': players,
          'bots': {for (final e in bots.entries) '${e.key}': e.value},
          'options': options,
        }),
      );
      ++saved.value;
    } catch (_) {
      // Without storage the game is played all the same; only the next setup starts empty.
    }
  }
}
