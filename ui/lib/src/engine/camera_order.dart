import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import 'engine_connection.dart';
import 'engine_events.dart';

/// The player's order and names of the engine's cameras: "Kamera 1" is the camera the player made first, whatever
/// order the engine reports them in, and a swap of two cameras is a swap here. Cameras are identified by the engine's
/// id, which follows the USB port. An engine that keeps the assignment itself is the source for every display; this
/// device's own store only serves engines that keep none.
class CameraOrder extends ChangeNotifier {
  CameraOrder([CameraOrderStore? store]) : _store = store ?? MemoryCameraOrderStore();

  final CameraOrderStore _store;
  List<String> _order = [];
  Map<String, String> _names = {};
  List<String> _localOrder = [];
  Map<String, String> _localNames = {};
  EngineConnection? _engine;
  bool _offered = false;

  /// Follows the engine's assignment while it keeps one
  void attach(EngineConnection engine) {
    _engine = engine;
    engine.addListener(_follow);
    _follow();
  }

  bool get _fromEngine => _engine?.cameraAssignment != null;

  void _follow() {
    final assignment = _engine?.cameraAssignment;
    if (assignment == null) {
      _offered = false;
      if (!listEquals(_order, _localOrder) || !mapEquals(_names, _localNames)) {
        _order = _localOrder;
        _names = _localNames;
        notifyListeners();
      }
      return;
    }
    final placed = assignment.cameras.where((c) => c.order != null).toList()
      ..sort((a, b) => a.order!.compareTo(b.order!));
    // An engine that has no assignment yet gets this device's, once: the PC's earlier assignment carries over.
    if (placed.isEmpty && _localOrder.isNotEmpty && !_offered) {
      _offered = true;
      _send(_localOrder, _localNames);
    }
    final order = [for (final c in placed) c.id];
    final names = {
      for (final c in assignment.cameras)
        if (c.name != null && c.name!.isNotEmpty) c.id: c.name!,
    };
    // The engine notifies often (camera status every second); only a changed assignment rebuilds.
    if (listEquals(order, _order) && mapEquals(names, _names)) return;
    _order = order;
    _names = names;
    notifyListeners();
  }

  @override
  void dispose() {
    _engine?.removeListener(_follow);
    super.dispose();
  }

  Future<String?> _send(List<String> order, Map<String, String> names) {
    final known = {for (final c in _engine!.cameraAssignment!.cameras) c.id};
    final ids = {...order, ...known};
    return _engine!.setCameraAssignment([
      for (final id in ids)
        AssignedCamera(id, order: order.contains(id) ? order.indexOf(id) + 1 : null, name: names[id]),
    ]);
  }

  Future<void> load() async {
    final (order, names) = await _store.load();
    _localOrder = order;
    _localNames = names;
    if (!_fromEngine) {
      _order = order;
      _names = names;
      notifyListeners();
    } else {
      _follow();
    }
  }

  /// `cameras` in the player's order; cameras the player has not placed yet follow in the engine's order
  List<String> sorted(List<String> cameras) => [
    for (final id in _order)
      if (cameras.contains(id)) id,
    for (final id in cameras)
      if (!_order.contains(id)) id,
  ];

  /// Whether a camera of `cameras` has not been placed by the player yet
  bool needsAssignment(List<String> cameras) => cameras.isNotEmpty && cameras.any((id) => !_order.contains(id));

  String? nameOf(String id) => _names[id];

  /// The player's name of the camera, or "Kamera N" by its place among `cameras`
  String label(AppLocalizations l10n, List<String> cameras, String id) {
    final name = _names[id];
    if (name != null && name.isNotEmpty) return name;
    final index = sorted(cameras).indexOf(id);
    return index < 0 ? id : l10n.cameraNumber(index + 1);
  }

  /// The order and names the player chose; cameras placed earlier that are not connected now keep their place after
  /// these
  Future<String?> assign(List<String> order, Map<String, String> names) async {
    final merged = [...order, ..._order.where((id) => !order.contains(id))];
    final trimmed = {..._names, for (final MapEntry(:key, :value) in names.entries) key: value.trim()}
      ..removeWhere((_, name) => name.isEmpty);
    if (_fromEngine) return _send(merged, trimmed);
    _order = _localOrder = merged;
    _names = _localNames = trimmed;
    notifyListeners();
    await _store.save(_order, _names);
    return null;
  }
}

abstract interface class CameraOrderStore {
  Future<(List<String>, Map<String, String>)> load();
  Future<void> save(List<String> order, Map<String, String> names);
}

class PrefsCameraOrderStore implements CameraOrderStore {
  static const _order = 'cameras.order';
  static const _names = 'cameras.names';

  @override
  Future<(List<String>, Map<String, String>)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final names = jsonDecode(prefs.getString(_names) ?? '{}');
    return (
      prefs.getStringList(_order) ?? <String>[],
      names is Map<String, dynamic> ? {for (final e in names.entries) e.key: '${e.value}'} : <String, String>{},
    );
  }

  @override
  Future<void> save(List<String> order, Map<String, String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_order, order);
    await prefs.setString(_names, jsonEncode(names));
  }
}

class MemoryCameraOrderStore implements CameraOrderStore {
  MemoryCameraOrderStore([this.order = const [], this.names = const {}]);

  List<String> order;
  Map<String, String> names;

  @override
  Future<(List<String>, Map<String, String>)> load() async => (List.of(order), Map.of(names));

  @override
  Future<void> save(List<String> order, Map<String, String> names) async {
    this.order = List.of(order);
    this.names = Map.of(names);
  }
}

class CameraOrderScope extends InheritedNotifier<CameraOrder> {
  const CameraOrderScope({super.key, required CameraOrder order, required super.child}) : super(notifier: order);

  static final CameraOrder _none = CameraOrder();

  /// The app's order; an empty one where none is given (widgets tested on their own)
  static CameraOrder of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CameraOrderScope>()?.notifier ?? _none;
}

/// The engine's cameras in the player's order
List<String> orderedCameras(BuildContext context) =>
    CameraOrderScope.of(context).sorted(EngineScope.of(context).hello?.cameras ?? const []);

/// The player's name of a camera of the connected engine, or "Kamera N"
String cameraLabel(BuildContext context, String id) =>
    CameraOrderScope.of(context)
        .label(AppLocalizations.of(context), EngineScope.of(context).hello?.cameras ?? const [], id);
