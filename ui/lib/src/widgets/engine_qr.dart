import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';

/// Virtual interfaces (libvirt, Docker, VPNs) that other devices in the home network cannot reach
final RegExp _virtualInterface = RegExp(r'^(lo|virbr|docker|br-|veth|tun|tap|wg|zt)');

/// This device's addresses in the home network, best first: private IPv4 on a physical interface
Future<List<String>> homeNetworkAddresses() async {
  final List<NetworkInterface> interfaces;
  try {
    interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  } on SocketException {
    return const [];
  }
  final addresses = [
    for (final i in interfaces)
      if (!_virtualInterface.hasMatch(i.name))
        for (final a in i.addresses)
          if (!a.isLoopback) a.address,
  ];
  int rank(String a) => a.startsWith('192.168.')
      ? 0
      : a.startsWith('10.')
      ? 1
      : 2;
  return addresses..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// The address of the engine on this device as a QR code, for a phone or tablet to scan; with the engine's PIN in it
/// where the engine asks for pairing (#110), so scanning also pairs.
class EngineQrDialog extends StatefulWidget {
  const EngineQrDialog({super.key, required this.port});

  final int port;

  @override
  State<EngineQrDialog> createState() => _EngineQrDialogState();
}

class _EngineQrDialogState extends State<EngineQrDialog> {
  late final Future<List<String>> _addresses = homeNetworkAddresses();
  bool _askedPin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    // Only an engine with pairing (#110) has a PIN; older ones answer with an error, which changes nothing.
    if (!_askedPin && engine.isConnected) {
      _askedPin = true;
      engine.requestPairingPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pin = EngineScope.of(context).pairingPin?.pin;
    final port = widget.port;
    return AlertDialog(
      title: Text(l10n.engineQrTitle),
      content: FutureBuilder<List<String>>(
        future: _addresses,
        builder: (context, snapshot) {
          final addresses = snapshot.data;
          if (addresses == null) return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
          if (addresses.isEmpty) return Text(l10n.engineQrNoNetwork);
          final url = 'ws://${addresses.first}:$port/${pin == null ? '' : '?pin=$pin'}';
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.engineQrHint),
              const SizedBox(height: 16),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(key: const ValueKey('engine-qr'), data: url, size: 240),
              ),
              const SizedBox(height: 12),
              SelectableText(url, key: const ValueKey('engine-qr-url')),
              if (pin != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.engineQrPin(pin),
                  key: const ValueKey('engine-qr-pin'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ],
          );
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close))],
    );
  }
}

/// Scanning works with a camera on phones and tablets; not in the browser, where Platform is unavailable.
bool get canScanQr => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// The engine address from a QR code (ws://… or wss://…); null when cancelled
Future<String?> scanEngineQr(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return scanQr(
    context,
    title: l10n.scanEngineQr,
    hint: l10n.scanEngineQrHint,
    unavailable: l10n.scanEngineQrUnavailable,
    accept: (value) => value.startsWith('ws://') || value.startsWith('wss://'),
  );
}

/// The first QR code that [accept] takes; null when cancelled
Future<String?> scanQr(
  BuildContext context, {
  required String title,
  required String hint,
  required String unavailable,
  required bool Function(String) accept,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (_) => _ScanPage(title: title, hint: hint, unavailable: unavailable, accept: accept),
  ),
);

class _ScanPage extends StatefulWidget {
  const _ScanPage({required this.title, required this.hint, required this.unavailable, required this.accept});

  final String title;
  final String hint;

  /// Shown when the camera cannot be used
  final String unavailable;
  final bool Function(String) accept;

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            // Without the camera, for instance when its permission is denied, the text field remains.
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(widget.unavailable, key: const ValueKey('qr-scanner-error'), textAlign: TextAlign.center),
              ),
            ),
            onDetect: (capture) {
              if (_done) return;
              for (final code in capture.barcodes) {
                final value = code.rawValue;
                if (value != null && widget.accept(value)) {
                  _done = true;
                  Navigator.of(context).pop(value);
                  return;
                }
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: Text(widget.hint, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}
