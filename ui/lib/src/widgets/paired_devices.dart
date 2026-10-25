import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';

/// The devices paired with the engine on this device (#110), each to unpair. Shown only where this app talks to its
/// engine locally, which the engine marks with `pairing: local`.
class PairedDevicesCard extends StatefulWidget {
  const PairedDevicesCard({super.key});

  @override
  State<PairedDevicesCard> createState() => _PairedDevicesCardState();
}

class _PairedDevicesCardState extends State<PairedDevicesCard> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (!_asked && engine.isConnected && engine.hello?.pairing == 'local') {
      _asked = true;
      engine.requestPairedClients();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    if (!engine.isConnected || engine.hello?.pairing != 'local') return const SizedBox.shrink();
    final clients = engine.pairedClients?.clients;
    final format = DateFormat.yMd(l10n.localeName).add_Hm();
    return Card(
      key: const ValueKey('paired-devices'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(leading: const Icon(Icons.devices), title: Text(l10n.pairedDevices)),
            if (clients == null || clients.isEmpty)
              ListTile(title: Text(l10n.noPairedDevices, style: Theme.of(context).textTheme.bodySmall))
            else
              for (final c in clients)
                ListTile(
                  key: ValueKey('paired-${c.id}'),
                  title: Text(c.client),
                  subtitle: c.lastSeen == null
                      ? null
                      : Text(l10n.pairedDeviceSeen(format.format(c.lastSeen!.toLocal()))),
                  trailing: TextButton(
                    key: ValueKey('unpair-${c.id}'),
                    onPressed: () => engine.unpair(c.id),
                    child: Text(l10n.unpairDevice),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
