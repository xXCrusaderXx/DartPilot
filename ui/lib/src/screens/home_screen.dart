import 'package:flutter/material.dart';

import '../theme.dart';
import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import 'around_the_clock_screen.dart';
import 'cricket_screen.dart';
import 'more_games_screen.dart';
import 'precision_training_screen.dart';
import 'training_screen.dart';
import 'watch_game_screen.dart';
import 'x01_setup_screen.dart';

/// The hub once the app is set up: the engine's state, the games to play locally or solo, and playing together.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onConnect});

  /// Opens the connection page, when playing without an engine
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modes = [
      (
        Icons.flag,
        l10n.modeX01,
        l10n.modeX01Description,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const X01SetupScreen())),
      ),
      (
        Icons.grid_on,
        l10n.modeCricket,
        l10n.modeCricketDescription,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: CricketScreen.setup)),
      ),
      (
        Icons.schedule,
        l10n.modeAroundTheClock,
        l10n.modeAroundTheClockDescription,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: AroundTheClockScreen.setup)),
      ),
      (
        Icons.adjust,
        l10n.modeTraining,
        l10n.modeTrainingDescription,
        () async {
          if (!await confirmBoardEmpty(context) || !context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrainingScreen()));
        },
      ),
      (
        Icons.blur_circular,
        l10n.modePrecision,
        l10n.modePrecisionDescription,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrecisionTrainingScreen())),
      ),
      (
        Icons.casino_outlined,
        l10n.modeMoreGames,
        l10n.modeMoreGamesDescription,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MoreGamesScreen())),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(onConnect: onConnect),
              const SharedGameCard(),
              const _InterruptedGameCard(),
              if (StatisticsScope.maybeOf(context)?.profiles.isEmpty ?? false) ...[
                const SizedBox(height: 16),
                Card(
                  key: const ValueKey('first-profile'),
                  child: ListTile(
                    leading: const Icon(Icons.person_add, size: 32),
                    title: Text(l10n.firstProfileTitle),
                    subtitle: Text(l10n.firstProfileText),
                    trailing: FilledButton(onPressed: () => createProfile(context), child: Text(l10n.newProfile)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(l10n.chooseGame, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final (icon, title, description, onTap) in modes)
                Card(
                  child: ListTile(
                    key: ValueKey('mode-$title'),
                    leading: Icon(icon, size: 32),
                    title: Text(title),
                    subtitle: Text(description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onTap,
                  ),
                ),
              const SizedBox(height: 24),
              Text(l10n.playTogether, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  key: const ValueKey('lobby'),
                  enabled: false,
                  leading: const Icon(Icons.groups, size: 32),
                  title: Text(l10n.lobby),
                  subtitle: Text(l10n.lobbyComingSoon),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line about the engine, and the board warning while darts are in it
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return EngineSelect(
      select: (engine) =>
          (engine.isConnected, engine.hello, engine.detection, engine.detectionReason, engine.calibration),
      builder: (context, _) => _card(context, EngineScope.read(context)),
    );
  }

  Widget _card(BuildContext context, EngineConnection engine) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final connected = engine.isConnected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  connected ? Icons.link : Icons.keyboard,
                  color: connected ? StatusColors.of(context).good : theme.disabledColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    connected
                        ? engine.hello?.mode == 'simulate'
                              ? '${l10n.engineConnected} (${l10n.engineSimulated})'
                              : l10n.engineConnected
                        : l10n.playingWithoutEngine,
                    key: const ValueKey('engine-state'),
                  ),
                ),
                if (!connected) TextButton(onPressed: onConnect, child: Text(l10n.connect)),
              ],
            ),
            // A setup step that is missing shows on the settings tab, not here; home keeps what matters while playing.
            if (connected &&
                engine.detection != 'running' &&
                engine.detectionReason != 'not_calibrated' &&
                engine.detectionReason != 'no_empty_reference')
              Padding(
                key: const ValueKey('detection-state'),
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Row(
                  children: [
                    Icon(
                      engine.detection == 'paused' ? Icons.pause_circle_outline : Icons.visibility_off_outlined,
                      color: StatusColors.of(context).warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(engine.detection == 'paused' ? l10n.detectionPaused : l10n.detectionUnavailable),
                    ),
                  ],
                ),
              ),
            if (connected) const BoardStateRow(),
          ],
        ),
      ),
    );
  }
}

/// A game the app was killed in: played on from where it stopped, or ended and kept as unfinished
class _InterruptedGameCard extends StatelessWidget {
  const _InterruptedGameCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statistics = StatisticsScope.maybeOf(context);
    final game = statistics?.interrupted;
    if (statistics == null || game == null) return const SizedBox.shrink();
    return Card(
      key: const ValueKey('interrupted-game'),
      child: ListTile(
        leading: const Icon(Icons.restore, size: 32),
        title: Text(l10n.interruptedGameTitle(gameTitle(l10n, game))),
        subtitle: Text(game.players.join(' · ')),
        trailing: Wrap(
          spacing: 8,
          children: [
            TextButton(
              key: const ValueKey('end-interrupted'),
              onPressed: () => statistics.settleInterrupted(resume: false),
              child: Text(l10n.endInterruptedGame),
            ),
            FilledButton(
              key: const ValueKey('resume-interrupted'),
              onPressed: () {
                statistics.settleInterrupted(resume: true);
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => gameScreenFor(game, watching: false)));
              },
              child: Text(l10n.resumeGame),
            ),
          ],
        ),
      ),
    );
  }
}
