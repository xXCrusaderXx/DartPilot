import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_choice.dart';
import '../engine/engine_connection.dart';
import '../board/dart_throw.dart';
import '../board/scoring.dart';
import '../sound/caller.dart';
import '../sound/effects.dart';
import '../sound/sfx.dart';
import '../sound/x01_calls.dart';
import '../widgets/appearance_preview.dart';
import '../widgets/appearance_share.dart';
import '../widgets/appearance_tiles.dart';
import '../widgets/board_check.dart';
import '../widgets/engine_card.dart';
import '../widgets/paired_devices.dart';
import 'about_screen.dart';
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

/// Everything that is set up rather than played, as a short overview: how the app looks, sound and caller, and the
/// cameras with their setup, each on a page of its own with a line on where it stands.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onConnect});

  /// Opens the choice of how darts are counted
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final caller = CallerScope.of(context);
    final sfx = SfxScope.of(context);
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                key: const ValueKey('settings-page-display'),
                leading: const Icon(Icons.palette_outlined),
                title: Text(l10n.settingsDisplay),
                subtitle: Text(l10n.settingsDisplayHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(AppearanceScreen(title: l10n.settingsDisplay, tiles: const DisplaySettingsTiles())),
              ),
              ListTile(
                key: const ValueKey('settings-page-game-screen'),
                leading: const Icon(Icons.scoreboard_outlined),
                title: Text(l10n.gameScreenLayout),
                subtitle: Text(l10n.settingsGameScreenHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    open(AppearanceScreen(title: l10n.gameScreenLayout, tiles: const GameScreenSettingsTiles())),
              ),
              ListTile(
                key: const ValueKey('settings-page-sound'),
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(l10n.settingsSound),
                subtitle: Text(
                  [
                    sfx.enabled ? l10n.settingsEffectsOn : l10n.settingsEffectsOff,
                    caller.enabled ? l10n.settingsCallerOn : l10n.settingsCallerOff,
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const SoundSettingsScreen()),
              ),
              _CamerasEntry(onOpen: () => open(CameraSettingsScreen(onConnect: onConnect))),
              ListTile(
                key: const ValueKey('settings-page-about'),
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.aboutTitle),
                subtitle: Text(l10n.aboutHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const AboutScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The overview's entry to the cameras: how darts are counted now, and a mark while a setup step is open
class _CamerasEntry extends StatelessWidget {
  const _CamerasEntry({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = CameraOrderScope.of(context);
    return EngineSelect(
      select: (engine) => (engine.isConnected, engine.state, engine.reconnecting, SetupStatus.of(engine, order)),
      builder: (context, state) {
        final (connected, connection, reconnecting, status) = state;
        final settings = EngineSettingsScope.maybeOf(context);
        final starting = chosenLocalEngineStarting(settings, LocalEngineScope.maybeOf(context)?.notifier);
        final summary = connected
            ? (status.needsAttention ? l10n.settingsSetupIncomplete : l10n.engineConnected)
            : reconnecting || connection == EngineConnectionState.connecting || starting
            ? l10n.engineConnecting
            : settings == null || settings.byHand || !settings.chosen || settings.pausedForNow
            ? l10n.settingsCamerasByHand
            : l10n.homeUnreachable;
        return ListTile(
          key: const ValueKey('settings-page-cameras'),
          leading: Badge(
            isLabelVisible: status.needsAttention,
            backgroundColor: StatusColors.of(context).warning,
            child: const Icon(Icons.videocam_outlined),
          ),
          title: Text(l10n.settingsCamerasPage),
          subtitle: Text(summary),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpen,
        );
      },
    );
  }
}

/// Sound on a page of its own: the effects and their volume, the score caller, vibration on a phone, and a sample
/// visit to hear them together
class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});

  /// The time between the darts of the sample visit
  static const Duration sampleDartTime = Duration(milliseconds: 450);

  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  final List<Timer> _sample = [];

  @override
  void dispose() {
    for (final t in _sample) {
      t.cancel();
    }
    super.dispose();
  }

  /// Three darts in the treble 20 as in a game: a thud for each, then the 180 from the caller or as an effect
  void _playSample() {
    for (final t in _sample) {
      t.cancel();
    }
    _sample.clear();
    final dart = DartThrow(fieldCentre(Ring.triple), ThrowInput.keypad);
    for (var i = 0; i < 3; ++i) {
      _sample.add(
        Timer(SoundSettingsScreen.sampleDartTime * i, () {
          if (!mounted) return;
          final last = i == 2;
          dartFeedback(
            context,
            dart,
            effect: last ? Effect.oneEighty : Effect.dart,
            calls: last ? const [callOneEighty] : const [],
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sfx = SfxScope.of(context);
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSound)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              section(l10n.soundSectionEffects),
              SwitchListTile(
                key: const ValueKey('sfx-enabled'),
                secondary: const Icon(Icons.graphic_eq),
                title: Text(l10n.soundEffects),
                subtitle: Text(l10n.soundEffectsHint),
                value: sfx.enabled,
                onChanged: (on) => sfx.set(enabled: on),
              ),
              if (sfx.enabled)
                ListTile(
                  leading: const Icon(Icons.volume_up_outlined),
                  title: Text(l10n.effectsVolume),
                  subtitle: Slider(
                    key: const ValueKey('sfx-volume'),
                    value: sfx.volume,
                    onChanged: (v) => sfx.set(volume: v, save: false),
                    // Kept once the slider is let go, then the thud of a dart at the new volume
                    onChangeEnd: (v) => sfx.set(volume: v).then((_) => sfx.play(Effect.dart)),
                  ),
                ),
              if (sfx.canVibrate)
                SwitchListTile(
                  key: const ValueKey('sfx-vibration'),
                  secondary: const Icon(Icons.vibration),
                  title: Text(l10n.vibration),
                  subtitle: Text(l10n.vibrationHint),
                  value: sfx.vibration,
                  onChanged: (on) => sfx.set(vibration: on),
                ),
              section(l10n.soundSectionCaller),
              const CallerSettings(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const ValueKey('sound-sample'),
                    onPressed: _playSample,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.soundSample),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cameras and the engine that runs them: the connection, the setup in the order it is done with where each
/// step stands, the cameras' pictures and the player's darts, and the tools for finding faults. Without an engine
/// one line says that cameras are optional.
class CameraSettingsScreen extends StatelessWidget {
  const CameraSettingsScreen({super.key, required this.onConnect});

  /// Opens the choice of how darts are counted
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
    void choose() {
      Navigator.of(context).popUntil((route) => route.isFirst);
      onConnect();
    }

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCamerasPage)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              section(l10n.settingsConnection),
              ListTile(
                key: const ValueKey('settings-connection'),
                leading: Icon(connected ? Icons.link : Icons.touch_app_outlined),
                title: Text(
                  connected
                      ? (onThisDevice ? l10n.connectedThisDevice : l10n.connectedNetwork)
                      : l10n.playingWithoutEngine,
                ),
                subtitle: connected ? Text(engine.url) : null,
                onTap: connected ? () => open(const EngineSettingsScreen()) : choose,
                trailing: connected
                    ? OutlinedButton(
                        key: const ValueKey('settings-disconnect'),
                        onPressed: () async {
                          final settings = EngineSettingsScope.maybeOf(context);
                          // The engine this app started goes with the connection; darts go in by hand from now on.
                          if (onThisDevice) await local!.notifier!.stop();
                          await engine.disconnect();
                          settings?.choose(byHand: true);
                        },
                        child: Text(l10n.disconnect),
                      )
                    : null,
              ),
              if (connected) ...[
                // The setup in the order it is done, each step with where it stands
                section(l10n.settingsSetup),
                ListTile(
                  key: const ValueKey('settings-cameras'),
                  leading: const Icon(Icons.videocam),
                  title: Text(l10n.cameras),
                  subtitle: Text(l10n.settingsCamerasHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(const CamerasScreen()),
                ),
                _SetupTile(
                  tileKey: const ValueKey('settings-assign-cameras'),
                  enabled: engine.hello?.cameras.isNotEmpty ?? false,
                  icon: Icons.swap_vert,
                  title: l10n.assignCameras,
                  subtitle: l10n.setupAssignHint,
                  state: status.assignment,
                  onTap: () => openSetupStep(context, SetupStep.assignment),
                ),
                _SetupTile(
                  tileKey: const ValueKey('settings-calibration'),
                  enabled: engine.calibration != null,
                  icon: Icons.straighten,
                  title: l10n.calibration,
                  subtitle: engine.calibration == null ? l10n.calibNeedsCameras : l10n.calibrationHint,
                  state: status.calibration,
                  onTap: () => openSetupStep(context, SetupStep.calibration),
                ),
                _SetupTile(
                  tileKey: const ValueKey('settings-calibration-check'),
                  enabled: engine.calibration != null,
                  icon: Icons.verified_outlined,
                  title: l10n.calibrationCheck,
                  subtitle: l10n.calibrationCheckHint,
                  state: status.check,
                  onTap: () => openSetupStep(context, SetupStep.check),
                ),
                _SetupTile(
                  tileKey: const ValueKey('settings-empty-board'),
                  enabled: true,
                  icon: Icons.crop_free,
                  title: l10n.storeEmptyReference,
                  subtitle: l10n.settingsEmptyBoardHint,
                  state: status.emptyBoard,
                  onTap: () => openSetupStep(context, SetupStep.emptyBoard),
                ),
                ListTile(
                  key: const ValueKey('open-my-darts'),
                  leading: const Icon(Icons.straighten_outlined),
                  title: Text(l10n.myDarts),
                  subtitle: Text(l10n.myDartsHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(const MyDartsScreen()),
                ),
                section(l10n.settingsAdvanced),
                _SetupTile(
                  tileKey: const ValueKey('open-diagnosis'),
                  enabled: true,
                  icon: Icons.troubleshoot,
                  title: l10n.diagnosis,
                  subtitle: l10n.settingsDiagnosisHint,
                  state: SetupState.none,
                  onTap: () => open(const DiagnosisScreen()),
                ),
                _SetupTile(
                  tileKey: const ValueKey('open-reference-run'),
                  enabled: true,
                  icon: Icons.my_location,
                  title: l10n.referenceRun,
                  subtitle: l10n.settingsReferenceHint,
                  state: SetupState.none,
                  onTap: () => open(const ReferenceRunScreen()),
                ),
              ] else ...[
                Padding(
                  key: const ValueKey('settings-cameras-optional'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    l10n.settingsCamerasOptional,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      key: const ValueKey('settings-connect'),
                      onPressed: choose,
                      icon: const Icon(Icons.videocam_outlined),
                      label: Text(l10n.homeConnectCameras),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the page of a setup step; the empty board is stored right away.
void openSetupStep(BuildContext context, SetupStep step) {
  void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  switch (step) {
    case SetupStep.assignment:
      open(const CameraAssignScreen());
    case SetupStep.calibration:
      open(const CalibrationScreen());
    case SetupStep.check:
      open(const CalibrationCheckScreen());
    case SetupStep.emptyBoard:
      storeEmptyBoard(context);
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

/// The score caller in the settings: on or off, and its volume
class CallerSettings extends StatefulWidget {
  const CallerSettings({super.key});

  @override
  State<CallerSettings> createState() => _CallerSettingsState();
}

class _CallerSettingsState extends State<CallerSettings> {
  /// The calls are English in every language: a device without an English voice would read them wrongly or not at all.
  bool? _available;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_available != null) return;
    CallerScope.of(context).voice.speaksEnglish.then((a) {
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
              onChanged: (v) => caller.set(volume: v, save: false),
              onChangeEnd: (v) => caller.set(volume: v),
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

/// How the app looks on this device: preset, brightness, colours and text
class DisplaySettingsTiles extends StatelessWidget {
  const DisplaySettingsTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = DisplayScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppearancePresetTiles(),
        ListTile(title: Text(l10n.brightness), subtitle: Text(l10n.brightnessHint)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<AppBrightness>(
            key: const ValueKey('brightness'),
            showSelectedIcon: false,
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
        const AppearanceShareTiles(),
      ],
    );
  }
}

/// How a game is shown on this device: display style, viewing distance, the layout and how it celebrates
class GameScreenSettingsTiles extends StatelessWidget {
  const GameScreenSettingsTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = DisplayScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(title: Text(l10n.displayStyle), subtitle: Text(l10n.displayStyleHint)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<DisplayStyle>(
            key: const ValueKey('display-style'),
            showSelectedIcon: false,
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
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: ViewingDistance.auto, label: Text(l10n.displayAuto)),
              ButtonSegment(value: ViewingDistance.near, label: Text(l10n.viewingNear)),
              ButtonSegment(value: ViewingDistance.far, label: Text(l10n.viewingFar)),
            ],
            selected: {display.distance},
            onSelectionChanged: (s) => display.set(distance: s.first),
          ),
        ),
        const GameScreenTiles(),
      ],
    );
  }
}

/// Settings of how the app looks beside a preview of a game screen, which follows every change: side by side where
/// the window is wide, the preview above them where it is not
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.title, required this.tiles});

  final String title;
  final Widget tiles;

  @override
  Widget build(BuildContext context) {
    final settings = SingleChildScrollView(child: tiles);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const preview = Padding(padding: EdgeInsets.all(16), child: AppearancePreview());
            if (constraints.maxWidth >= WindowClass.mediumFrom && constraints.maxWidth > constraints.maxHeight) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: preview),
                  SizedBox(width: 420, child: settings),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: constraints.maxHeight * 0.4, child: preview),
                const Divider(height: 1),
                Expanded(child: settings),
              ],
            );
          },
        ),
      ),
    );
  }
}
