import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_choice.dart';
import '../engine/engine_connection.dart';
import '../sound/caller.dart';
import '../sound/x01_calls.dart';
import '../widgets/board_check.dart';
import '../widgets/engine_card.dart';
import '../widgets/paired_devices.dart';
import 'calibration_check_screen.dart';
import 'calibration_screen.dart';
import 'cameras_screen.dart';
import 'diagnosis_screen.dart';
import 'my_darts_screen.dart';
import 'reference_run_screen.dart';

/// Everything that is set up rather than played: the connection, the cameras, the setup diagnosis and calibration.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onConnect});

  /// Opens the connection page, when playing without an engine
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final engine = EngineScope.of(context);
    final local = LocalEngineScope.maybeOf(context);
    final connected = engine.isConnected;
    final onThisDevice = local?.settings.mode == EngineMode.thisDevice;
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
              ListTile(
                key: const ValueKey('open-diagnosis'),
                enabled: connected,
                leading: const Icon(Icons.troubleshoot),
                title: Text(l10n.diagnosis),
                subtitle: Text(l10n.settingsDiagnosisHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const DiagnosisScreen()),
              ),
              ListTile(
                key: const ValueKey('open-reference-run'),
                enabled: connected,
                leading: const Icon(Icons.my_location),
                title: Text(l10n.referenceRun),
                subtitle: Text(l10n.settingsReferenceHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const ReferenceRunScreen()),
              ),
              ListTile(
                key: const ValueKey('settings-empty-board'),
                enabled: connected,
                leading: const Icon(Icons.crop_free),
                title: Text(l10n.storeEmptyReference),
                subtitle: Text(l10n.settingsEmptyBoardHint),
                onTap: () => storeEmptyBoard(context),
              ),
              section(l10n.scoreCaller),
              const CallerSettings(),
              section(l10n.settingsCalibration),
              ListTile(
                key: const ValueKey('settings-calibration'),
                enabled: connected && engine.calibration != null,
                leading: const Icon(Icons.straighten),
                title: Text(l10n.calibration),
                subtitle: Text(engine.calibration == null ? l10n.calibNeedsCameras : l10n.calibrationHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const CalibrationScreen()),
              ),
              ListTile(
                key: const ValueKey('settings-calibration-check'),
                enabled: connected && engine.calibration != null,
                leading: const Icon(Icons.verified_outlined),
                title: Text(l10n.calibrationCheck),
                subtitle: Text(l10n.calibrationCheckHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const CalibrationCheckScreen()),
              ),
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
