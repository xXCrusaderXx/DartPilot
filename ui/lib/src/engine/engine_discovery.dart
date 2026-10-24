// Finds engines in the home network (#109, ADR 0008): mDNS/DNS-SD `_dartpilot._tcp`, and a UDP broadcast for
// networks that block multicast between Wi-Fi and LAN.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:multicast_dns/multicast_dns.dart';

/// An engine that answered a search
class FoundEngine {
  const FoundEngine({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    this.version = '',
    this.mode = '',
  });

  /// Stable per engine, so the same engine found twice (both ways, or under two addresses) is listed once
  final String id;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final String version;

  /// live or simulate
  final String mode;

  /// The app speaks dartpilot/1.x; other majors are listed but cannot be used.
  bool get compatible => protocol.startsWith('dartpilot/1.');

  String get address => host.contains(':') ? '[$host]:$port' : '$host:$port';

  String get url => 'ws://$address/';

  /// Reply to a broadcast search; null for anything else
  static FoundEngine? fromReply(Map<String, dynamic> json, String host) {
    if (json['type'] != 'engine' || json['port'] is! int) return null;
    return FoundEngine(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? host,
      host: host,
      port: json['port'] as int,
      protocol: json['protocol'] as String? ?? '',
      version: json['version'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
    );
  }

  /// From the TXT entries (key=value) of an mDNS service
  static FoundEngine fromTxt(Map<String, String> txt, String host, int port) => FoundEngine(
    id: txt['id'] ?? '',
    name: txt['name'] ?? host,
    host: host,
    port: port,
    protocol: txt['protocol'] ?? '',
    version: txt['version'] ?? '',
    mode: txt['mode'] ?? '',
  );

  /// Key for listing an engine once: its id, or its address for engines without one
  String get key => id.isNotEmpty ? id : address;
}

/// One way of searching; yields the engines it finds until [timeout] ends.
typedef DiscoverySource = Stream<FoundEngine> Function(Duration timeout);

class EngineDiscovery {
  EngineDiscovery(this.sources);

  /// mDNS and UDP broadcast; no sources where dart:io sockets are missing (web)
  factory EngineDiscovery.network() => EngineDiscovery(kIsWeb ? const [] : [mdnsSearch, broadcastSearch()]);

  final List<DiscoverySource> sources;

  bool get available => sources.isNotEmpty;

  /// All engines found so far, each time one is added; ends when every source has finished
  Stream<List<FoundEngine>> search({Duration timeout = const Duration(seconds: 3)}) {
    final found = <String, FoundEngine>{};
    final controller = StreamController<List<FoundEngine>>();
    var running = sources.length;
    if (running == 0) {
      controller.close();
      return controller.stream;
    }
    for (final source in sources) {
      source(timeout).listen(
        (engine) {
          // The first answer wins; an mDNS host name and a broadcast IP of the same engine are one entry.
          if (found.containsKey(engine.key)) return;
          found[engine.key] = engine;
          controller.add(List.unmodifiable(found.values));
        },
        // A source that cannot search (no network, port in use) leaves the others searching.
        onError: (Object _) {},
        onDone: () {
          if (--running == 0) controller.close();
        },
      );
    }
    return controller.stream;
  }
}

const int discoveryPort = 8485;
const String serviceType = '_dartpilot._tcp';

/// Asks every engine in the local network by UDP broadcast; they answer to the asking socket.
DiscoverySource broadcastSearch({InternetAddress? target, int port = discoveryPort}) => (timeout) async* {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final replies = StreamController<FoundEngine>();
  try {
    socket.broadcastEnabled = true;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      try {
        final json = jsonDecode(utf8.decode(datagram.data));
        final engine = json is Map<String, dynamic> ? FoundEngine.fromReply(json, datagram.address.address) : null;
        if (engine != null) replies.add(engine);
      } on FormatException {
        // Not an engine's answer
      }
    });
    final request = utf8.encode(jsonEncode({'type': 'discover', 'protocol': 'dartpilot/1.0'}));
    final address = target ?? InternetAddress('255.255.255.255');
    // UDP may drop a datagram; asking twice costs nothing, and the engine limits its answers per asker.
    socket.send(request, address, port);
    Timer(timeout ~/ 3, () => socket.send(request, address, port));
    Timer(timeout, replies.close);
    yield* replies.stream;
  } finally {
    socket.close();
  }
};

/// DNS-SD lookup of `_dartpilot._tcp.local`: PTR → SRV (host, port) and TXT (id, name, protocol, …) → IPv4 address.
Stream<FoundEngine> mdnsSearch(Duration timeout) async* {
  final client = MDnsClient();
  await client.start();
  try {
    final ptrs = await client
        .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('$serviceType.local'), timeout: timeout)
        .toList();
    for (final instance in {for (final p in ptrs) p.domainName}) {
      final srv = await client
          .lookup<SrvResourceRecord>(ResourceRecordQuery.service(instance), timeout: const Duration(seconds: 1))
          .first
          .timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException(instance));
      final txt = await client
          .lookup<TxtResourceRecord>(ResourceRecordQuery.text(instance), timeout: const Duration(seconds: 1))
          .toList();
      final ips = await client
          .lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
            timeout: const Duration(seconds: 1),
          )
          .toList();
      final host = ips.isEmpty ? srv.target : pickAddress([for (final ip in ips) ip.address], await _localAddresses());
      yield FoundEngine.fromTxt(parseTxt(txt.map((t) => t.text)), host, srv.port);
    }
  } on TimeoutException {
    // An instance that does not answer its SRV query is skipped with the rest of this search.
  } finally {
    client.stop();
  }
}

Future<List<InternetAddress>> _localAddresses() async {
  try {
    return [
      for (final interface in await NetworkInterface.list(type: InternetAddressType.IPv4)) ...interface.addresses,
    ];
  } on SocketException {
    return const [];
  }
}

/// An engine host answers with every address it has, including virtual bridges (libvirt, Docker) that other devices
/// cannot reach. The address in the same /24 network as one of this device's addresses is the one to use.
String pickAddress(List<InternetAddress> candidates, List<InternetAddress> local) {
  String prefix(InternetAddress a) => a.address.substring(0, a.address.lastIndexOf('.'));
  final networks = {for (final a in local) prefix(a)};
  for (final candidate in candidates) {
    if (networks.contains(prefix(candidate))) return candidate.address;
  }
  return candidates.first.address;
}

/// TXT records as key=value; multicast_dns joins the strings of one record with newlines
Map<String, String> parseTxt(Iterable<String> records) => {
  for (final record in records)
    for (final entry in record.split('\n'))
      if (entry.contains('=')) entry.substring(0, entry.indexOf('=')): entry.substring(entry.indexOf('=') + 1),
};
