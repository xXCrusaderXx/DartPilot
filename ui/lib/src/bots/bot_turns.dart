import 'dart:async';

import 'package:flutter/widgets.dart';

import '../board/dart_throw.dart';
import '../games/dart_game.dart';
import 'bot.dart';

/// For game screens: whenever a bot is at the oche, its darts are thrown one after the other, each after a short
/// pause so the players can follow them on the board.
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

  bool get isBotTurn => !botGame.isFinished && botPlayers.containsKey(playerAtOche);

  /// Call after every build: starts the bot's next dart if a bot is at the oche.
  void scheduleBotTurn() {
    if (_timer != null || !isBotTurn) return;
    _timer = Timer(pause, () {
      _timer = null;
      if (!mounted || !isBotTurn) return;
      final player = playerAtOche;
      final bot = _bots.putIfAbsent(player, () => Bot(botLevel(botPlayers[player]!)));
      addBotDart(bot.nextDart(botGame));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
