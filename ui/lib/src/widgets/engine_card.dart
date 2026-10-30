import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../../l10n/app_localizations.dart';
import '../engine/engine_choice.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_discovery.dart';
import '../engine/engine_errors.dart';
import '../engine/engine_manager.dart';
import 'engine_qr.dart';

/// The engine the app plays against, in the settings: its own on this device (where it can run one), or one in the
/// network by address or search, with the connection state.
class EngineCard extends StatefulWidget {
  const EngineCard({super.key});

  @override
  State<EngineCard> createState() => _EngineCardState();
}

class _EngineCardState extends State<EngineCard> {
  Future<void> _setMode(EngineMode mode) async {
    final local = LocalEngineScope.maybeOf(context)!;
    final engine = EngineScope.of(context);
    setState(() => local.settings.mode = mode);
    unawaited(local.settings.save());
    if (mode == EngineMode.network) {
      await local.notifier!.stop();
      await engine.disconnect();
    } else {
      await startLocalEngine(local.notifier!, engine, local.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final theme = Theme.of(context);
    final (icon, color, text) = switch (engine.state) {
      EngineConnectionState.connected => (
        Icons.link,
        StatusColors.of(context).good,
        engine.hello?.mode == 'simulate' ? l10n.engineConnectedSimulated : l10n.engineConnected,
      ),
      _ when engine.reconnecting => (Icons.sync, StatusColors.of(context).warning, l10n.engineReconnecting),
      EngineConnectionState.connecting => (Icons.sync, theme.colorScheme.secondary, l10n.engineConnecting),
      EngineConnectionState.failed => (Icons.link_off, StatusColors.of(context).bad, l10n.engineFailed),
      EngineConnectionState.disconnected => (Icons.link_off, theme.disabledColor, l10n.engineDisconnected),
    };
    final local = LocalEngineScope.maybeOf(context);
    final onThisDevice = local?.settings.mode == EngineMode.thisDevice;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (engine.state == EngineConnectionState.connecting || engine.reconnecting)
                  const SizedBox.square(
                    dimension: 24,
                    child: Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(l10n.engine, style: theme.textTheme.titleMedium),
                const SizedBox(width: 12),
                Expanded(child: Text(text, key: const ValueKey('engine-state'))),
              ],
            ),
            if (local != null) ...[
              const SizedBox(height: 12),
              SegmentedButton<EngineMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: EngineMode.thisDevice,
                    icon: const Icon(Icons.computer),
                    label: Text(l10n.engineThisDevice),
                  ),
                  ButtonSegment(
                    value: EngineMode.network,
                    icon: const Icon(Icons.lan),
                    label: Text(l10n.engineNetwork),
                  ),
                ],
                selected: {local.settings.mode},
                onSelectionChanged: (s) => _setMode(s.first),
              ),
            ],
            const SizedBox(height: 8),
            if (onThisDevice) LocalEnginePanel(local: local!) else const NetworkEnginePanel(),
          ],
        ),
      ),
    );
  }
}

/// An engine in the network: the one connected, or the ones found by a search, and the address by hand or from a QR
/// code where the search finds nothing. Connecting remembers the engine for the next start.
class NetworkEnginePanel extends StatefulWidget {
  const NetworkEnginePanel({super.key});

  @override
  State<NetworkEnginePanel> createState() => _NetworkEnginePanelState();
}

class _NetworkEnginePanelState extends State<NetworkEnginePanel> {
  // Created once; the connection notifies on every state change, which must not reset what the user typed.
  TextEditingController? _controller;

  // Where no engine runs on this device, the address of this device is no use as a suggestion.
  TextEditingController get _url => _controller ??= TextEditingController(text: _suggestedUrl());

  String _suggestedUrl() {
    final url = EngineSettingsScope.maybeOf(context)?.url ?? EngineScope.of(context).url;
    return url == EngineConnection.defaultUrl && LocalEngineScope.maybeOf(context) == null ? '' : url;
  }

  StreamSubscription<List<FoundEngine>>? _search;
  bool _searching = false;

  /// Result of the last search; null before the first one
  List<FoundEngine>? _found;

  /// The player asked for the address field
  bool _manual = false;

  @override
  void dispose() {
    _search?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startSearch() {
    _search?.cancel();
    setState(() {
      _searching = true;
      _found = const [];
    });
    _search = EngineScope.of(context).discovery
        .search()
        .listen((found) => setState(() => _found = found), onDone: () => setState(() => _searching = false));
  }

  void _connectTo(FoundEngine engine) {
    _url.text = engine.url;
    _connect();
  }

  void _connect() {
    final url = _url.text.trim();
    final settings = EngineSettingsScope.maybeOf(context);
    if (settings != null) {
      settings
        ..url = url
        ..mode = EngineMode.network
        ..save();
    }
    EngineScope.of(context).connect(url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final theme = Theme.of(context);
    if (engine.isConnected) {
      return Row(
        children: [
          Expanded(child: Text(engine.url, key: const ValueKey('connected-url'))),
          OutlinedButton(onPressed: engine.disconnect, child: Text(l10n.disconnect)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (engine.state == EngineConnectionState.failed && !engine.reconnecting)
          Row(
            children: [
              Expanded(
                child: Text(
                  connectionErrorText(l10n, engine.error) ?? engine.error ?? '',
                  key: const ValueKey('engine-error'),
                  style: theme.textTheme.bodySmall?.copyWith(color: StatusColors.of(context).bad),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('engine-retry'),
                onPressed: () => engine.connect(engine.url),
                child: Text(l10n.engineRetry),
              ),
            ],
          ),
        ..._networkSearch(l10n, theme, engine),
        if (_showManual(engine)) ...[
          const SizedBox(height: 8),
          _AddressRow(
            field: TextField(
              key: const ValueKey('engine-address'),
              controller: _url,
              decoration: InputDecoration(
                labelText: l10n.engineAddress,
                hintText: 'ws://192.168.1.20:8484/',
                isDense: true,
              ),
            ),
            buttons: [
              if (canScanQr) ...[
                IconButton(
                  key: const ValueKey('engine-scan'),
                  onPressed: () async {
                    final url = await scanEngineQr(context);
                    if (url == null || !mounted) return;
                    _url.text = url;
                    _connect();
                  },
                  tooltip: l10n.scanEngineQr,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton(onPressed: _connect, child: Text(l10n.connect)),
            ],
          ),
        ],
      ],
    );
  }

  /// The address by hand (and the QR code) only when the search cannot be used, found nothing, or is asked for
  bool _showManual(EngineConnection engine) =>
      _manual || !engine.discovery.available || (!_searching && (_found?.isEmpty ?? false));

  /// Engines in the network, searched for by itself when this view opens
  List<Widget> _networkSearch(AppLocalizations l10n, ThemeData theme, EngineConnection engine) {
    if (!engine.discovery.available) return const [];
    if (_found == null && !_searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _found == null && !_searching) _startSearch();
      });
    }
    final found = _found ?? const <FoundEngine>[];
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              _searching && found.isEmpty
                  ? l10n.searchingEngines
                  : found.isEmpty
                  ? l10n.noEnginesFound
                  : l10n.foundEngines,
              style: found.isEmpty ? theme.textTheme.bodySmall : theme.textTheme.labelLarge,
            ),
          ),
          if (_searching)
            const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
              key: const ValueKey('engine-search'),
              onPressed: _startSearch,
              tooltip: l10n.searchEngines,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      for (final e in found)
        ListTile(
          key: ValueKey('found-${e.key}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(e.compatible ? Icons.dns : Icons.block),
          title: Text(e.name),
          subtitle: Text(
            [
              e.address,
              if (e.mode == 'simulate') l10n.engineSimulated,
              if (e.version.isNotEmpty) e.version,
              if (!e.compatible) l10n.engineIncompatible(e.protocol),
            ].join('  ·  '),
          ),
          enabled: e.compatible,
          onTap: e.compatible ? () => _connectTo(e) : null,
        ),
      if (!_showManual(engine))
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('engine-manual'),
            onPressed: () => setState(() => _manual = true),
            child: Text(l10n.enterAddressManually),
          ),
        ),
    ];
  }
}

/// The engine this app runs: its state, whether it uses the cameras, start and stop, and its log.
class LocalEnginePanel extends StatelessWidget {
  const LocalEnginePanel({super.key, required this.local});

  final LocalEngineScope local;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final manager = local.notifier!;
    final settings = local.settings;
    final busy = manager.state == LocalEngineState.starting || manager.state == LocalEngineState.running;
    final text = switch (manager.state) {
      LocalEngineState.stopped => l10n.localEngineStopped,
      LocalEngineState.starting => l10n.localEngineStarting,
      LocalEngineState.running => l10n.localEngineRunning(manager.url ?? ''),
      LocalEngineState.failed => switch (manager.error) {
        LocalEngineError.notFound => l10n.localEngineNotFound,
        LocalEngineError.noCameras => l10n.localEngineNoCameras,
        LocalEngineError.portInUse => l10n.localEnginePortInUse,
        LocalEngineError.noAnswer => l10n.localEngineNoAnswer,
        LocalEngineError.liveUnavailable => l10n.localEngineLiveUnavailable,
        _ => l10n.localEngineCrashed,
      },
    };
    final started = manager.startedWith;
    final changed =
        manager.state == LocalEngineState.running &&
        started != null &&
        started !=
            (simulate: settings.simulate, cameras: settings.simulate ? settings.cameras : true, share: settings.share);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text,
          key: const ValueKey('local-engine-state'),
          style: manager.state == LocalEngineState.failed ? TextStyle(color: theme.colorScheme.error) : null,
        ),
        StatefulBuilder(
          builder: (inner, setState) => Column(
            children: [
              SwitchListTile(
                key: const ValueKey('simulate-darts'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.simulateDarts),
                subtitle: Text(l10n.simulateDartsHint),
                value: settings.simulate,
                onChanged: manager.state == LocalEngineState.starting
                    ? null
                    : (value) {
                        settings.simulate = value;
                        (context as Element).markNeedsBuild();
                        settings.save();
                      },
              ),
              // Live detection always needs the cameras; only simulated darts can do without them.
              if (settings.simulate)
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 16),
                  title: Text(l10n.useCameras),
                  subtitle: Text(l10n.useCamerasHint),
                  value: settings.cameras,
                  onChanged: manager.state == LocalEngineState.starting
                      ? null
                      : (value) {
                          settings.cameras = value;
                          (context as Element).markNeedsBuild();
                          settings.save();
                        },
                ),
              SwitchListTile(
                key: const ValueKey('share-engine'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.shareEngine),
                subtitle: Text(l10n.shareEngineHint),
                value: settings.share,
                onChanged: manager.state == LocalEngineState.starting
                    ? null
                    : (value) {
                        settings.share = value;
                        (context as Element).markNeedsBuild();
                        settings.save();
                      },
              ),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (changed)
              FilledButton.icon(
                key: const ValueKey('local-engine-restart'),
                onPressed: () => startLocalEngine(manager, EngineScope.of(context), settings),
                icon: const Icon(Icons.restart_alt),
                label: Text(l10n.restartEngine),
              ),
            if (manager.state == LocalEngineState.running &&
                (manager.startedWith?.share ?? false) &&
                manager.port != null)
              TextButton.icon(
                key: const ValueKey('show-engine-qr'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => EngineQrDialog(port: manager.port!),
                ),
                icon: const Icon(Icons.qr_code_2),
                label: Text(l10n.showEngineQr),
              ),
            if (manager.state == LocalEngineState.failed && manager.error == LocalEngineError.notFound)
              TextButton.icon(
                key: const ValueKey('engine-choose-program'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _EngineLogDialog(local: local),
                ),
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(l10n.engineChooseProgram),
              ),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _EngineLogDialog(local: local),
              ),
              icon: const Icon(Icons.article_outlined),
              label: Text(l10n.engineLog),
            ),
            busy
                ? OutlinedButton.icon(
                    key: const ValueKey('local-engine-stop'),
                    onPressed: () async {
                      final engine = EngineScope.of(context);
                      await manager.stop();
                      await engine.disconnect();
                    },
                    icon: const Icon(Icons.stop),
                    label: Text(l10n.stopEngine),
                  )
                : FilledButton.icon(
                    key: const ValueKey('local-engine-start'),
                    onPressed: () => startLocalEngine(manager, EngineScope.of(context), settings),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.startEngine),
                  ),
          ],
        ),
      ],
    );
  }
}

/// The local engine's output, and the program it runs
class _EngineLogDialog extends StatefulWidget {
  const _EngineLogDialog({required this.local});

  final LocalEngineScope local;

  @override
  State<_EngineLogDialog> createState() => _EngineLogDialogState();
}

class _EngineLogDialogState extends State<_EngineLogDialog> {
  late final TextEditingController _program = TextEditingController(
    text: widget.local.settings.executable ?? widget.local.notifier!.resolvedExecutable ?? '',
  );

  @override
  void dispose() {
    _program.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final manager = LocalEngineScope.maybeOf(context)?.notifier ?? widget.local.notifier!;
    return AlertDialog(
      title: Text(l10n.engineLog),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _program,
              decoration: InputDecoration(labelText: l10n.engineProgram, helperText: l10n.engineProgramHint),
              onSubmitted: _saveProgram,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black,
                child: SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(
                    manager.log.isEmpty ? l10n.engineLogEmpty : manager.log.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _saveProgram(_program.text);
            Navigator.of(context).pop();
          },
          child: Text(l10n.close),
        ),
      ],
    );
  }

  void _saveProgram(String value) {
    final settings = widget.local.settings;
    final program = value.trim();
    // An empty field or the program found anyway means: keep finding it automatically.
    settings.executable = program.isEmpty || program == findEngineExecutable() ? null : program;
    settings.save();
  }
}

/// The address field with its buttons: in one line, or the buttons under the field where a phone is too narrow.
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.field, required this.buttons});

  final Widget field;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 520
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: 8),
              Wrap(alignment: WrapAlignment.end, runSpacing: 8, children: buttons),
            ],
          )
        : Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 12),
              ...buttons,
            ],
          ),
  );
}
