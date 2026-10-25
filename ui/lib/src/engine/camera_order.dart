import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import 'engine_connection.dart';

/// The player's order and names of the engine's cameras: "Kamera 1" is the camera the player made first, whatever
/// order the engine reports them in, and a swap of two cameras is a swap here. Cameras are identified by the engine's
/// id, which follows the USB port.
class CameraOrder extends ChangeNotifier {
  CameraOrder([CameraOrderStore? store]) : _store = store ?? MemoryCameraOrderStore();

  final CameraOrderStore _store;
  List<String> _order = [];
  Map<String, String> _names = {};

  Future<void> load() async {
    final (order, names) = await _store.load();
    _order = order;
    _names = names;
    notifyListeners();
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
  Future<void> assign(List<String> order, Map<String, String> names) async {
    _order = [...order, ..._order.where((id) => !order.contains(id))];
    _names = {..._names, for (final MapEntry(:key, :value) in names.entries) key: value.trim()}
      ..removeWhere((_, name) => name.isEmpty);
    notifyListeners();
    await _store.save(_order, _names);
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
