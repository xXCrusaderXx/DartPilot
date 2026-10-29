import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_choice.dart';
import '../engine/engine_connection.dart';
import '../sound/caller.dart';
import '../sound/x01_calls.dart';
import '../widgets/appearance_tiles.dart';
import '../widgets/board_check.dart';
import '../widgets/engine_card.dart';
import '../widgets/paired_devices.dart';
import 'calibration_check_screen.dart';
import 'calibration_screen.dart';
import 'cameras_screen.dart';
import 'diagnosis_screen.dart';
import 'my_darts_screen.dart';
import 'reference_run_screen.dart';
import '../engine/setup_status.dart';
import 'camera_assign_screen.dart';
import '../engine/camera_order.dart';
import '../theme.dart';
import '../display.dart';

/// Everything that is set up rather than played: the connection, the cameras, the setup diagnosis and calibration.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onConnect});

  /// Opens the connection page, when playing without an engine
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    // The page shows only these values of the connection; other engine events leave it alone.
    return EngineSelect(
      select: (engine) => (engine.isConnected, engine.url, engine.calibration, engine.boardState, engine.hello),
      builder: (context, _) => _page(context, EngineScope.read(context)),
    );
  }

  Widget _page(BuildContext context, EngineConnection engine) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final local = LocalEngineScope.maybeOf(context);
    final connected = engine.isConnected;
    final onThisDevice = local?.settings.mode == EngineMode.thisDevice;
    final status = SetupStatus.of(engine, CameraOrderScope.of(context));
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              section(l10n.settingsConnection),
              ListTile(
                key: const ValueKey('settings-connection'),
                leading: Icon(connected ? Icons.link : Icons.link_off),
                title: Text(
                  connected
                      ? (onThisDevice ? l10n.connectedThisDevice : l10n.connectedNetwork)
                      : l10n.playingWithoutEngine,
                ),
                subtitle: Text(connected ? engine.url : l10n.playingWithoutEngineHint),
                onTap: () => open(const EngineSettingsScreen()),
                trailing: connected
                    ? OutlinedButton(
                        key: const ValueKey('settings-disconnect'),
                        onPressed: () async {
                          // The engine this app started goes with the connection.
                          if (onThisDevice) await local!.notifier!.stop();
                          await engine.disconnect();
                        },
                        child: Text(l10n.disconnect),
                      )
                    : FilledButton(onPressed: onConnect, child: Text(l10n.connect)),
              ),
              // The setup in the order it is done, each step with where it stands
              section(l10n.settingsSetup),
              _SetupTile(
                tileKey: const ValueKey('settings-assign-cameras'),
                enabled: connected && (engine.hello?.cameras.isNotEmpty ?? false),
                icon: Icons.swap_vert,
                title: l10n.assignCameras,
                subtitle: l10n.setupAssignHint,
                state: status.assignment,
                onTap: () => open(const CameraAssignScreen()),
              ),
              _SetupTile(
                tileKey: const ValueKey('settings-calibration'),
                enabled: connected && engine.calibration != null,
                icon: Icons.straighten,
                title: l10n.calibration,
                subtitle: engine.calibration == null ? l10n.calibNeedsCameras : l10n.calibrationHint,
                state: status.calibration,
                onTap: () => open(const CalibrationScreen()),
              ),
              _SetupTile(
                tileKey: const ValueKey('settings-calibration-check'),
                enabled: connected && engine.calibration != null,
                icon: Icons.verified_outlined,
                title: l10n.calibrationCheck,
                subtitle: l10n.calibrationCheckHint,
                state: status.check,
                onTap: () => open(const CalibrationCheckScreen()),
              ),
              _SetupTile(
                tileKey: const ValueKey('settings-empty-board'),
                enabled: connected,
                icon: Icons.crop_free,
                title: l10n.storeEmptyReference,
                subtitle: l10n.settingsEmptyBoardHint,
                state: status.emptyBoard,
                onTap: () => storeEmptyBoard(context),
              ),
              _SetupTile(
                tileKey: const ValueKey('open-diagnosis'),
                enabled: connected,
                icon: Icons.troubleshoot,
                title: l10n.diagnosis,
                subtitle: l10n.settingsDiagnosisHint,
                state: SetupState.none,
                onTap: () => open(const DiagnosisScreen()),
              ),
              _SetupTile(
                tileKey: const ValueKey('open-reference-run'),
                enabled: connected,
                icon: Icons.my_location,
                title: l10n.referenceRun,
                subtitle: l10n.settingsReferenceHint,
                state: SetupState.none,
                onTap: () => open(const ReferenceRunScreen()),
              ),
              section(l10n.settingsCamerasBoard),
              ListTile(
                key: const ValueKey('settings-cameras'),
                enabled: connected,
                leading: const Icon(Icons.videocam),
                title: Text(l10n.cameras),
                subtitle: Text(l10n.settingsCamerasHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const CamerasScreen()),
              ),
              ListTile(
                key: const ValueKey('open-my-darts'),
                enabled: connected,
                leading: const Icon(Icons.straighten_outlined),
                title: Text(l10n.myDarts),
                subtitle: Text(l10n.myDartsHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const MyDartsScreen()),
              ),
              section(l10n.settingsDisplay),
              const DisplaySettingsTiles(),
              section(l10n.scoreCaller),
              const CallerSettings(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The engine itself, reachable while connected: where it runs, its options (simulated darts, cameras, sharing in
/// the network with its QR code), start, stop and its log.
class EngineSettingsScreen extends StatelessWidget {
  const EngineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).engineSettings)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(padding: const EdgeInsets.all(16), children: const [EngineCard(), PairedDevicesCard()]),
      ),
    ),
  );
}

/// The score caller in the settings: on or off, its volume, and a test phrase
class CallerSettings extends StatefulWidget {
  const CallerSettings({super.key});

  @override
  State<CallerSettings> createState() => _CallerSettingsState();
}

class _CallerSettingsState extends State<CallerSettings> {
  bool? _available;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_available != null) return;
    CallerScope.of(context).voice.available.then((a) {
      if (mounted) setState(() => _available = a);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final caller = CallerScope.of(context);
    final available = _available ?? true;
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('caller-enabled'),
          secondary: const Icon(Icons.record_voice_over_outlined),
          title: Text(l10n.scoreCaller),
          subtitle: Text(available ? l10n.scoreCallerHint : l10n.callerNoVoice),
          value: caller.enabled && available,
          onChanged: available ? (on) => caller.set(enabled: on) : null,
        ),
        if (caller.enabled && available)
          ListTile(
            leading: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.callerVolume),
            subtitle: Slider(
              key: const ValueKey('caller-volume'),
              value: caller.volume,
              onChanged: (v) => caller.set(volume: v),
            ),
            trailing: TextButton(
              key: const ValueKey('caller-test'),
              onPressed: () => caller.call([callOneEighty], callLanguage),
              child: Text(l10n.callerTest),
            ),
          ),
      ],
    );
  }
}

/// A setup step: its page, and on the right where it stands
class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.tileKey,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onTap,
  });

  /// On the list tile itself, where tests and the other settings entries have theirs
  final Key tileKey;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final SetupState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colours = StatusColors.of(context);
    // Shape as well as colour: a tick, an exclamation mark or a clock
    final (IconData? mark, Color? colour, String? text) = switch (state) {
      SetupState.done => (Icons.check_circle, colours.good, l10n.setupDone),
      SetupState.missing => (Icons.error_outline, colours.warning, l10n.setupMissing),
      SetupState.stale => (Icons.update, colours.warning, l10n.setupStale),
      SetupState.problem => (Icons.report_problem_outlined, colours.bad, l10n.setupProblem),
      SetupState.none => (null, null, null),
    };
    return ListTile(
      key: tileKey,
      enabled: enabled,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: mark == null || !enabled
          ? const Icon(Icons.chevron_right)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(mark, color: colour, size: 20),
                const SizedBox(width: 4),
                Text(text!, style: TextStyle(color: colour)),
              ],
            ),
      onTap: onTap,
    );
  }
}

/// How the app looks on this device: preset, brightness, colours, text size, game display and viewing distance
class DisplaySettingsTiles extends StatelessWidget {
  const DisplaySettingsTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = DisplayScope.of(context);
    return Column(
      children: [
        const AppearancePresetTiles(),
        ListTile(title: Text(l10n.brightness), subtitle: Text(l10n.brightnessHint)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<AppBrightness>(
            key: const ValueKey('brightness'),
            segments: [
              ButtonSegment(value: AppBrightness.system, label: Text(l10n.brightnessSystem)),
              ButtonSegment(value: AppBrightness.dark, label: Text(l10n.brightnessDark)),
              ButtonSegment(value: AppBrightness.light, label: Text(l10n.brightnessLight)),
            ],
            selected: {display.brightness},
            onSelectionChanged: (s) => display.set(brightness: s.first),
          ),
        ),
        const AppearanceColourTiles(),
        ListTile(title: Text(l10n.displayStyle), subtitle: Text(l10n.displayStyleHint)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<DisplayStyle>(
            key: const ValueKey('display-style'),
            segments: [
              ButtonSegment(value: DisplayStyle.auto, label: Text(l10n.displayAuto)),
              ButtonSegment(value: DisplayStyle.clear, label: Text(l10n.displayStyleClear)),
              ButtonSegment(value: DisplayStyle.scoreboard, label: Text(l10n.displayStyleScoreboard)),
            ],
            selected: {display.style},
            onSelectionChanged: (s) => display.set(style: s.first),
          ),
        ),
        ListTile(title: Text(l10n.viewingDistance), subtitle: Text(l10n.viewingDistanceHint)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<ViewingDistance>(
            key: const ValueKey('viewing-distance'),
            segments: [
              ButtonSegment(value: ViewingDistance.auto, label: Text(l10n.displayAuto)),
              ButtonSegment(value: ViewingDistance.near, label: Text(l10n.viewingNear)),
              ButtonSegment(value: ViewingDistance.far, label: Text(l10n.viewingFar)),
            ],
            selected: {display.distance},
            onSelectionChanged: (s) => display.set(distance: s.first),
          ),
        ),
      ],
    );
  }
}
