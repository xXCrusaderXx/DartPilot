import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_discovery.dart';
import '../screens/cameras_screen.dart';
import 'board_check.dart';

/// Engine address, connect button and connection state, on the home screen, with a search for engines in the network.
class EngineCard extends StatefulWidget {
  const EngineCard({super.key});

  @override
  State<EngineCard> createState() => _EngineCardState();
}

class _EngineCardState extends State<EngineCard> {
  // Created once; the connection notifies on every state change, which must not reset what the user typed.
  TextEditingController? _controller;

  TextEditingController get _url => _controller ??= TextEditingController(text: EngineScope.of(context).url);

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
    EngineScope.of(context).connect(engine.url);
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _url,
                    enabled: !connected,
                    decoration: InputDecoration(labelText: l10n.engineAddress, isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
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
                    : FilledButton(onPressed: () => engine.connect(_url.text.trim()), child: Text(l10n.connect)),
              ],
            ),
            if (!connected && _found != null) ..._foundList(l10n, theme),
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
