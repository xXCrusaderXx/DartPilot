import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which dart set each player throws (#120), so that the engine detects with the darts of the player at the board.
/// Players are the profiles of this device, matched by name like the statistics; sets are the engine's ids.
class DartLinks extends ChangeNotifier {
  DartLinks([DartLinksStore? store]) : _store = store ?? MemoryDartLinksStore();

  final DartLinksStore _store;
  Map<String, String> _links = {};

  Future<void> load() async {
    _links = await _store.load();
    notifyListeners();
  }

  /// The set `player` throws; null when none is linked
  String? setOf(String player) => _links[player.toLowerCase()];

  /// Players linked to `setId`, as stored (lower case)
  Iterable<String> playersOf(String setId) => _links.entries.where((e) => e.value == setId).map((e) => e.key);

  Future<void> link(String player, String? setId) async {
    if (setId == null) {
      _links.remove(player.toLowerCase());
    } else {
      _links[player.toLowerCase()] = setId;
    }
    notifyListeners();
    await _store.save(_links);
  }

  /// After a set was deleted, its players throw without a set
  Future<void> forgetSet(String setId) async {
    _links.removeWhere((_, id) => id == setId);
    notifyListeners();
    await _store.save(_links);
  }
}

abstract interface class DartLinksStore {
  Future<Map<String, String>> load();
  Future<void> save(Map<String, String> links);
}

class PrefsDartLinksStore implements DartLinksStore {
  static const _key = 'darts.links';

  @override
  Future<Map<String, String>> load() async {
    final json = jsonDecode((await SharedPreferences.getInstance()).getString(_key) ?? '{}');
    return json is Map<String, dynamic> ? {for (final e in json.entries) e.key: '${e.value}'} : {};
  }

  @override
  Future<void> save(Map<String, String> links) async =>
      (await SharedPreferences.getInstance()).setString(_key, jsonEncode(links));
}

class MemoryDartLinksStore implements DartLinksStore {
  MemoryDartLinksStore([Map<String, String>? links]) : links = links ?? {};

  Map<String, String> links;

  @override
  Future<Map<String, String>> load() async => Map.of(links);

  @override
  Future<void> save(Map<String, String> links) async => this.links = Map.of(links);
}

class DartLinksScope extends InheritedNotifier<DartLinks> {
  const DartLinksScope({super.key, required DartLinks links, required super.child}) : super(notifier: links);

  static final DartLinks _none = DartLinks();

  static DartLinks of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DartLinksScope>()?.notifier ?? _none;

  /// Without rebuilding when links change, for game screens that only look up the player at the board
  static DartLinks read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DartLinksScope>()?.notifier ?? _none;
}
