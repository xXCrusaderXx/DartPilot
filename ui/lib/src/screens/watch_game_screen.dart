import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../games/x01.dart';
import '../stats/game_record.dart';
import 'around_the_clock_screen.dart';
import 'checkout_screen.dart';
import 'cricket_screen.dart';
import 'doubles_screen.dart';
import 'grouping_screen.dart';
import 'killer_screen.dart';
import 'round_game_screen.dart';
import 'x01_screen.dart';

/// The game another app leads, as that app shows it (#116). Every shared update rebuilds it from the record with the
/// same game rules, so both displays always agree.
class WatchGameScreen extends StatelessWidget {
  const WatchGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Only a change of the shared game rebuilds it; other engine events, such as camera status, do not.
    return EngineSelect(select: (engine) => engine.sharedGame, builder: _build);
  }

  Widget _build(BuildContext context, SharedGame? shared) {
    final l10n = AppLocalizations.of(context);
    final record = GameRecord.tryParse(shared?.game);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.watchGame)),
        body: Center(child: Text(l10n.sharedGameEnded, key: const ValueKey('shared-game-ended'))),
      );
    }
    // A new key per state: the screen is rebuilt from the record, not updated in place.
    final key = ValueKey('${record.id}-${record.throws.length}-${record.throws.lastOrNull?.point.hashCode}');
    return gameScreenFor(record, key: key, watching: true);
  }
}

/// The screen of a game, at the state of its record: to watch another display's game, or to play on in an
/// interrupted one.
Widget gameScreenFor(GameRecord record, {Key? key, required bool watching}) {
  return switch (record.mode) {
    GameMode.x01 => X01Screen(
      key: key,
      settings: X01Settings(
        players: record.players,
        startScore: record.x01Settings.startScore,
        doubleIn: record.x01Settings.doubleIn,
        doubleOut: record.x01Settings.doubleOut,
        legsToWin: record.x01Settings.legsToWin,
      ),
      bots: record.bots,
      replay: record.throws,
      watching: watching,
    ),
    GameMode.cricket => CricketScreen(
      key: key,
      names: record.players,
      cutThroat: record.settings['cut_throat'] == true,
      bots: record.bots,
      replay: record.throws,
      watching: watching,
    ),
    GameMode.aroundTheClock => AroundTheClockScreen(
      key: key,
      names: record.players,
      endWithBull: record.settings['end_with_bull'] == true,
      bots: record.bots,
      replay: record.throws,
      watching: watching,
    ),
    GameMode.grouping => GroupingScreen(
      key: key,
      player: record.players.first,
      target: record.groupingTarget,
      dartCount: record.groupingGame.dartCount,
      replay: record.throws,
      watching: watching,
    ),
    GameMode.doubles => DoublesScreen(
      key: key,
      player: record.players.first,
      targets: record.doublesGame.targets,
      dartsPerTarget: record.doublesGame.dartsPerTarget,
      replay: record.throws,
      watching: watching,
    ),
    GameMode.checkout => CheckoutScreen(
      key: key,
      player: record.players.first,
      starts: record.checkoutTrainer.starts,
      dartsPerAttempt: record.checkoutTrainer.dartsPerAttempt,
      ladder: record.checkoutTrainer.ladder,
      replay: record.throws,
      watching: watching,
    ),
    GameMode.killer => KillerScreen(
      key: key,
      names: record.players,
      numbers: record.killerGame.numbers,
      lives: record.killerGame.lives,
      bots: record.bots,
      replay: record.throws,
      watching: watching,
    ),
    GameMode.shanghai || GameMode.bobs27 || GameMode.halveIt => RoundGameScreen(
      key: key,
      mode: record.mode,
      names: record.players,
      settings: record.settings,
      bots: record.bots,
      replay: record.throws,
      watching: watching,
    ),
  };
}

/// What a game is, in a few words: "501", "Cricket", "Gruppieren T20"
String gameTitle(AppLocalizations l10n, GameRecord record) => switch (record.mode) {
  GameMode.x01 => '${record.x01Settings.startScore}',
  GameMode.cricket => l10n.modeCricket,
  GameMode.aroundTheClock => l10n.modeAroundTheClock,
  GameMode.grouping => '${l10n.modeGrouping} ${record.groupingTarget.label}',
  GameMode.doubles => l10n.modeDoubles,
  GameMode.checkout => l10n.modeCheckout,
  GameMode.shanghai || GameMode.bobs27 || GameMode.halveIt => RoundGameScreen.title(l10n, record.mode),
  GameMode.killer => l10n.modeKiller,
};

/// On home: a game another display leads, to watch here
class SharedGameCard extends StatelessWidget {
  const SharedGameCard({super.key});

  @override
  Widget build(BuildContext context) {
    return EngineSelect(select: (engine) => engine.sharedGame, builder: _build);
  }

  Widget _build(BuildContext context, SharedGame? shared) {
    final l10n = AppLocalizations.of(context);
    if (shared == null || shared.client == EngineScope.read(context).clientName || shared.game == null) {
      return const SizedBox.shrink();
    }
    final record = GameRecord.tryParse(shared.game);
    if (record == null) return const SizedBox.shrink();
    final mode = gameTitle(l10n, record);
    return Card(
      key: const ValueKey('shared-game'),
      child: ListTile(
        leading: const Icon(Icons.connected_tv, size: 32),
        title: Text(l10n.watchGameTitle(mode)),
        subtitle: Text(record.players.join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WatchGameScreen())),
      ),
    );
  }
}
