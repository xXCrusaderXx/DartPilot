import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_choice.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_discovery.dart';
import '../engine/engine_manager.dart';
import '../screens/cameras_screen.dart';
import 'board_check.dart';

/// The engine the app plays against, on the home screen: its own on this device (where it can run one), or one in
/// the network by address or search, with the connection state.
class EngineCard extends StatefulWidget {
  const EngineCard({super.key});

  @override
  State<EngineCard> createState() => _EngineCardState();
}

class _EngineCardState extends State<EngineCard> {
  // Created once; the connection notifies on every state change, which must not reset what the user typed.
  TextEditingController? _controller;

  TextEditingController get _url => _controller ??= TextEditingController(
    text: LocalEngineScope.maybeOf(context)?.settings.url ?? EngineScope.of(context).url,
  );

  StreamSubscription<List<FoundEngine>>? _search;
  bool _searching = false;

  /// Result of the last search; null before the first one
  List<FoundEngine>? _found;

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
    final local = LocalEngineScope.maybeOf(context);
    if (local != null) {
      local.settings.url = url;
      local.settings.save();
    }
    EngineScope.of(context).connect(url);
  }

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
        Colors.greenAccent,
        engine.hello?.mode == 'simulate' ? '${l10n.engineConnected} (${l10n.engineSimulated})' : l10n.engineConnected,
      ),
      EngineConnectionState.connecting => (Icons.sync, theme.colorScheme.secondary, l10n.engineConnecting),
      EngineConnectionState.failed => (Icons.link_off, theme.colorScheme.error, l10n.engineFailed),
      EngineConnectionState.disconnected => (Icons.link_off, theme.disabledColor, l10n.engineDisconnected),
    };
    final connected = engine.state == EngineConnectionState.connected;
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
            if (onThisDevice) ...[
              const SizedBox(height: 8),
              _LocalEngineSection(local: local!),
              if (connected) _CamerasButton(l10n: l10n),
            ] else ...[
              const SizedBox(height: 8),
              _AddressRow(
                field: TextField(
                  controller: _url,
                  enabled: !connected,
                  decoration: InputDecoration(labelText: l10n.engineAddress, isDense: true),
                ),
                buttons: [
                  if (!connected && engine.discovery.available) ...[
                    IconButton(
                      key: const ValueKey('engine-search'),
                      onPressed: _searching ? null : _startSearch,
                      tooltip: l10n.searchEngines,
                      icon: _searching
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.travel_explore),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (connected) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CamerasScreen())),
                      icon: const Icon(Icons.videocam),
                      label: Text(l10n.cameras),
                    ),
                    const SizedBox(width: 8),
                  ],
                  connected
                      ? OutlinedButton(onPressed: engine.disconnect, child: Text(l10n.disconnect))
                      : FilledButton(onPressed: _connect, child: Text(l10n.connect)),
                ],
              ),
              if (!connected && _found != null) ..._foundList(l10n, theme),
            ],
            if (connected) const BoardStateRow(),
          ],
        ),
      ),
    );
  }

  List<Widget> _foundList(AppLocalizations l10n, ThemeData theme) {
    final found = _found!;
    if (found.isEmpty) {
      return [
        const SizedBox(height: 8),
        Text(_searching ? l10n.searchingEngines : l10n.noEnginesFound, style: theme.textTheme.bodySmall),
      ];
    }
    return [
      const SizedBox(height: 8),
      Text(l10n.foundEngines, style: theme.textTheme.labelLarge),
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
    ];
  }
}

class _CamerasButton extends StatelessWidget {
  const _CamerasButton({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CamerasScreen())),
      icon: const Icon(Icons.videocam),
      label: Text(l10n.cameras),
    ),
  );
}

/// The engine this app runs: its state, whether it uses the cameras, start and stop, and its log.
class _LocalEngineSection extends StatelessWidget {
  const _LocalEngineSection({required this.local});

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
        _ => l10n.localEngineCrashed,
      },
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text,
          key: const ValueKey('local-engine-state'),
          style: manager.state == LocalEngineState.failed ? TextStyle(color: theme.colorScheme.error) : null,
        ),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.useCameras),
            subtitle: Text(l10n.useCamerasHint),
            value: settings.cameras,
            onChanged: busy
                ? null
                : (value) {
                    setState(() => settings.cameras = value);
                    settings.save();
                  },
          ),
        ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
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
