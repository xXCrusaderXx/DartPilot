import 'package:flutter/material.dart';

import '../theme.dart';
import '../../l10n/app_localizations.dart';
import '../engine/camera_order.dart';
import '../engine/engine_connection.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import 'around_the_clock_screen.dart';
import 'calibration_screen.dart';
import 'camera_assign_screen.dart';
import 'cricket_screen.dart';
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
              if (EngineScope.of(context).isConnected &&
                  CameraOrderScope.of(context).needsAssignment(EngineScope.of(context).hello?.cameras ?? const [])) ...[
                const SizedBox(height: 16),
                Card(
                  key: const ValueKey('assign-cameras-prompt'),
                  child: ListTile(
                    leading: const Icon(Icons.videocam_outlined, size: 32),
                    title: Text(l10n.newCamerasTitle),
                    subtitle: Text(l10n.newCamerasText),
                    trailing: FilledButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => const CameraAssignScreen())),
                      child: Text(l10n.assignCameras),
                    ),
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final engine = EngineScope.of(context);
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
            if (connected && engine.detection != 'running')
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
                      child: Text(switch ((engine.detection, engine.detectionReason)) {
                        (_, 'not_calibrated') => l10n.detectionNotCalibrated,
                        (_, 'no_empty_reference') => l10n.detectionWaitingForEmptyBoard,
                        ('paused', _) => l10n.detectionPaused,
                        _ => l10n.detectionUnavailable,
                      }),
                    ),
                  ],
                ),
              ),
            if (connected) const BoardStateRow(),
            if (connected)
              for (final camera in orderedCameras(context))
                if (engine.calibration?.of(camera)?.check?.needsCalibration ?? false)
                  Padding(
                    key: ValueKey('calibration-warning-$camera'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: StatusColors.of(context).bad),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            engine.calibration!.of(camera)!.check!.state == 'wrong_port'
                                ? l10n.homeCameraWrongPort(cameraLabel(context, camera))
                                : l10n.homeCameraMoved(cameraLabel(context, camera)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => CalibrationScreen(startCamera: camera))),
                          child: Text(l10n.calibMeasureAgain),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
