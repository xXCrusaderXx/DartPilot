import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';

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

/// The address of the engine on this device as a QR code, for a phone or tablet to scan
class EngineQrDialog extends StatelessWidget {
  const EngineQrDialog({super.key, required this.port});

  final int port;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.engineQrTitle),
      content: FutureBuilder<List<String>>(
        future: homeNetworkAddresses(),
        builder: (context, snapshot) {
          final addresses = snapshot.data;
          if (addresses == null) return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
          if (addresses.isEmpty) return Text(l10n.engineQrNoNetwork);
          final url = 'ws://${addresses.first}:$port/';
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
            ],
          );
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close))],
    );
  }
}

/// Scanning works with a camera on phones and tablets.
bool get canScanQr => Platform.isAndroid || Platform.isIOS;

/// The engine address from a QR code (ws://… or wss://…); null when cancelled
Future<String?> scanEngineQr(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanEngineQr)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              for (final code in capture.barcodes) {
                final value = code.rawValue;
                if (value != null && (value.startsWith('ws://') || value.startsWith('wss://'))) {
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
              child: Text(l10n.scanEngineQrHint, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}
