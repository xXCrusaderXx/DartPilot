import 'dart:async';

import 'package:flutter/widgets.dart';

import '../board/dart_throw.dart';
import '../games/dart_game.dart';
import 'bot.dart';

/// For game screens: whenever a bot is at the oche, its darts are thrown one after the other, each after a short
/// pause so the players can follow them on the board. An undo goes back past the bots' darts to the last dart of a
/// person, so a player can take back their own dart with one press while the bot plays on.
mixin BotTurns<T extends StatefulWidget> on State<T> {
  /// Bot level per player index; players without an entry are people
  Map<int, int> get botPlayers;
  DartGame get botGame;
  int get playerAtOche;

  /// Adds a bot's dart exactly as a player's dart is added
  void addBotDart(DartThrow dart);

  static const Duration pause = Duration(milliseconds: 900);

  Timer? _timer;
  final Map<int, Bot> _bots = {};

  /// True while the darts of the last visit are still in the board
  bool get waitsForTakeout => false;

  bool get isBotTurn => !botGame.isFinished && botPlayers.containsKey(playerAtOche);

  /// The number of darts when the bot's next dart was last considered; fewer now means an undo
  int? _darts;

  /// Call after every build: starts the bot's next dart if a bot is at the oche.
  void scheduleBotTurn() {
    final darts = botGame.throws.length;
    if (_darts != null && darts < _darts!) _undone();
    _darts = botGame.throws.length;
    if (_timer != null || !isBotTurn || waitsForTakeout) return;
    final scheduled = botGame.throws.length;
    _timer = Timer(pause, () {
      _timer = null;
      // A dart added or taken back meanwhile changed whose turn it is; the next build looks again.
      if (!mounted || !isBotTurn || waitsForTakeout || botGame.throws.length != scheduled) return;
      final player = playerAtOche;
      final bot = _bots.putIfAbsent(player, () => Bot(botLevel(botPlayers[player]!)));
      addBotDart(bot.nextDart(botGame));
    });
  }

  /// Call when darts were taken out without an undo, such as a dart rejected on another display: the bots play on from
  /// the darts as they are now.
  void dartsReplaced() {
    _timer?.cancel();
    _timer = null;
    _darts = botGame.throws.length;
  }

  /// After an undo that left a bot at the oche: its pending dart is dropped, and the bots' darts are taken back up to
  /// and including the last dart of a person, which is the one the player meant to undo.
  void _undone() {
    _timer?.cancel();
    _timer = null;
    if (!isBotTurn) return;
    // Undoing a bot's first dart of its visit puts the person before it back at the oche, without their last dart.
    final game = botGame;
    while (game.throws.isNotEmpty && botPlayers.containsKey(playerAtOche)) {
      game.undo();
    }
    _darts = game.throws.length;
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
