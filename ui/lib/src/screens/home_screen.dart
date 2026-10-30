import 'package:flutter/material.dart';

import '../display.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';
import '../engine/camera_order.dart';
import '../engine/engine_choice.dart';
import '../engine/engine_connection.dart';
import '../engine/setup_status.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import 'around_the_clock_screen.dart';
import 'cricket_screen.dart';
import 'more_games_screen.dart';
import 'precision_training_screen.dart';
import 'settings_screen.dart';
import 'training_screen.dart';
import 'watch_game_screen.dart';
import 'x01_setup_screen.dart';

/// The hub once the app is set up: how darts are counted right now, and the games.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onConnect});

  /// Opens the choice of how darts are counted
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modes = [
      (
        Icons.scoreboard_outlined,
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
    final window = WindowClass.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: window == WindowClass.large ? 1080 : 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(onConnect: onConnect),
              const _SetupHint(),
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
                    trailing: FilledButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final name = await createProfile(context);
                        if (name == null) return;
                        messenger.showSnackBar(
                          SnackBar(key: const ValueKey('profile-created'), content: Text(l10n.profileCreated(name))),
                        );
                      },
                      child: Text(l10n.newProfile),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(l10n.chooseGame, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (window == WindowClass.compact)
                for (final (icon, title, description, onTap) in modes)
                  Card(
                    child: ListTile(
                      key: ValueKey('mode-$title'),
                      leading: Icon(icon, size: 32, color: theme.colorScheme.primary),
                      title: Text(title),
                      subtitle: Text(description),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onTap,
                    ),
                  )
              else
                _ModeGrid(columns: window == WindowClass.large ? 3 : 2, modes: modes),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Mode = (IconData icon, String title, String description, VoidCallback onTap);

/// The games as tiles in rows of [columns], each row as high as its tallest tile
class _ModeGrid extends StatelessWidget {
  const _ModeGrid({required this.columns, required this.modes});

  final int columns;
  final List<_Mode> modes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var start = 0; start < modes.length; start += columns)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + columns; ++i)
                  Expanded(
                    child: i >= modes.length
                        ? const SizedBox.shrink()
                        : Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: ValueKey('mode-${modes[i].$2}'),
                              onTap: modes[i].$4,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(modes[i].$1, size: 40, color: theme.colorScheme.primary),
                                    const SizedBox(height: 12),
                                    Text(modes[i].$2, style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      modes[i].$3,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One line on how darts are counted right now, and the board warning while darts are in it
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return EngineSelect(
      select: (engine) => (
        engine.state,
        engine.reconnecting,
        engine.hello,
        engine.detection,
        engine.detectionReason,
        engine.calibration,
      ),
      builder: (context, _) => _card(context, EngineScope.read(context)),
    );
  }

  Widget _card(BuildContext context, EngineConnection engine) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = StatusColors.of(context);
    final settings = EngineSettingsScope.maybeOf(context);
    final connected = engine.isConnected;
    final byHand = settings == null || settings.byHand || !settings.chosen;
    final trying = engine.reconnecting || engine.state == EngineConnectionState.connecting;
    // Connected, by hand, on the way to the engine, or the engine chosen but out of reach
    final (Widget icon, String text, List<Widget> actions) = connected
        ? (
            Icon(Icons.link, color: colours.good),
            engine.hello?.mode == 'simulate' ? l10n.homeConnectedSimulated : l10n.homeConnected,
            const <Widget>[],
          )
        : trying
        ? (
            const SizedBox.square(
              dimension: 24,
              child: Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            // The banner above says that the connection is lost; this line says what to do meanwhile.
            engine.reconnecting ? l10n.homeReconnecting : l10n.homeConnecting,
            const <Widget>[],
          )
        : byHand
        ? (
            Icon(Icons.touch_app_outlined, color: theme.colorScheme.onSurfaceVariant),
            l10n.playingWithoutEngine,
            [
              TextButton(
                key: const ValueKey('home-connect'),
                onPressed: onConnect,
                child: Text(l10n.homeConnectCameras),
              ),
            ],
          )
        : (
            Icon(Icons.link_off, color: colours.warning),
            l10n.homeUnreachable,
            [
              TextButton(key: const ValueKey('home-change'), onPressed: onConnect, child: Text(l10n.homeChange)),
              TextButton(
                key: const ValueKey('home-retry'),
                onPressed: () => connectChosenEngine(settings, engine, LocalEngineScope.maybeOf(context)?.notifier),
                child: Text(l10n.engineRetry),
              ),
            ],
          );
    final inline = actions.length == 1 && WindowClass.of(context) != WindowClass.compact;
    // A flat line, not a card: cards are for what can be played
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(child: Text(text, key: const ValueKey('engine-state'))),
                if (inline) ...actions,
              ],
            ),
            // On a phone, or with two of them, the ways on go below the line, where there is room for them
            if (!inline && actions.isNotEmpty) Wrap(alignment: WrapAlignment.end, children: actions),
            // A missing setup step has a line of its own below; this one says only what holds the darts back now.
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
                      color: colours.warning,
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

/// While cameras are connected but their setup is not finished: one line that opens the first open step, until the
/// player hides it for this session
class _SetupHint extends StatefulWidget {
  const _SetupHint();

  @override
  State<_SetupHint> createState() => _SetupHintState();
}

class _SetupHintState extends State<_SetupHint> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final order = CameraOrderScope.of(context);
    return EngineSelect(
      select: (engine) => (engine.hello?.cameras.isNotEmpty ?? false) ? SetupStatus.of(engine, order).firstOpen : null,
      builder: (context, step) {
        if (step == null) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final name = switch (step) {
          SetupStep.assignment => l10n.assignCameras,
          SetupStep.calibration => l10n.calibration,
          SetupStep.check => l10n.calibrationCheck,
          SetupStep.emptyBoard => l10n.storeEmptyReference,
        };
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
            key: const ValueKey('setup-hint'),
            child: ListTile(
              leading: Icon(Icons.build_circle_outlined, color: StatusColors.of(context).warning),
              title: Text(l10n.setupHintTitle),
              subtitle: Text(l10n.setupHintNext(name)),
              onTap: () => openSetupStep(context, step),
              trailing: IconButton(
                key: const ValueKey('setup-hint-hide'),
                tooltip: l10n.setupHintHide,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _hidden = true),
              ),
            ),
          ),
        );
      },
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
