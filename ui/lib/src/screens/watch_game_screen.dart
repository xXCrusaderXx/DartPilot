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
import 'x01_screen.dart';

/// The game another app leads, as that app shows it (#116). Every shared update rebuilds it from the record with the
/// same game rules, so both displays always agree.
class WatchGameScreen extends StatelessWidget {
  const WatchGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shared = EngineScope.of(context).sharedGame;
    final record = shared?.game == null ? null : GameRecord.fromJson(shared!.game!);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.watchGame)),
        body: Center(child: Text(l10n.sharedGameEnded, key: const ValueKey('shared-game-ended'))),
      );
    }
    // A new key per state: the screen is rebuilt from the record, not updated in place.
    final key = ValueKey('${record.id}-${record.throws.length}-${record.throws.lastOrNull?.point.hashCode}');
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
        watching: true,
      ),
      GameMode.cricket => CricketScreen(
        key: key,
        names: record.players,
        bots: record.bots,
        replay: record.throws,
        watching: true,
      ),
      GameMode.aroundTheClock => AroundTheClockScreen(
        key: key,
        names: record.players,
        endWithBull: record.settings['end_with_bull'] == true,
        bots: record.bots,
        replay: record.throws,
        watching: true,
      ),
      GameMode.grouping => GroupingScreen(
        key: key,
        player: record.players.first,
        target: record.groupingTarget,
        dartCount: record.groupingGame.dartCount,
        replay: record.throws,
        watching: true,
      ),
      GameMode.doubles => DoublesScreen(
        key: key,
        player: record.players.first,
        targets: record.doublesGame.targets,
        dartsPerTarget: record.doublesGame.dartsPerTarget,
        replay: record.throws,
        watching: true,
      ),
      GameMode.checkout => CheckoutScreen(
        key: key,
        player: record.players.first,
        starts: record.checkoutTrainer.starts,
        dartsPerAttempt: record.checkoutTrainer.dartsPerAttempt,
        replay: record.throws,
        watching: true,
      ),
    };
  }
}

/// On home: a game another display leads, to watch here
class SharedGameCard extends StatelessWidget {
  const SharedGameCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final SharedGame? shared = engine.sharedGame;
    if (shared == null || shared.client == engine.clientName || shared.game == null) return const SizedBox.shrink();
    final record = GameRecord.fromJson(shared.game!);
    if (record == null) return const SizedBox.shrink();
    final mode = switch (record.mode) {
      GameMode.x01 => '${record.x01Settings.startScore}',
      GameMode.cricket => l10n.modeCricket,
      GameMode.aroundTheClock => l10n.modeAroundTheClock,
      GameMode.grouping => '${l10n.modeGrouping} ${record.groupingTarget.label}',
      GameMode.doubles => l10n.modeDoubles,
      GameMode.checkout => l10n.modeCheckout,
    };
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
