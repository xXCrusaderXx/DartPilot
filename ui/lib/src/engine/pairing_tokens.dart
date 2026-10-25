import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The tokens this device got from pairing with engines (#110), by engine id. A token stands for this device; the
/// engine keeps only its hash.
abstract interface class PairingTokens {
  Future<String?> tokenFor(String engineId);
  Future<void> store(String engineId, String token);
  Future<void> forget(String engineId);
}

class PrefsPairingTokens implements PairingTokens {
  static const _key = 'engine.pairing_tokens';

  Future<Map<String, String>> _load() async {
    final json = jsonDecode((await SharedPreferences.getInstance()).getString(_key) ?? '{}');
    return json is Map<String, dynamic> ? {for (final e in json.entries) e.key: '${e.value}'} : {};
  }

  Future<void> _save(Map<String, String> tokens) async =>
      (await SharedPreferences.getInstance()).setString(_key, jsonEncode(tokens));

  @override
  Future<String?> tokenFor(String engineId) async => (await _load())[engineId];

  @override
  Future<void> store(String engineId, String token) async => _save((await _load())..[engineId] = token);

  @override
  Future<void> forget(String engineId) async => _save((await _load())..remove(engineId));
}

class MemoryPairingTokens implements PairingTokens {
  final Map<String, String> tokens = {};

  @override
  Future<String?> tokenFor(String engineId) async => tokens[engineId];

  @override
  Future<void> store(String engineId, String token) async => tokens[engineId] = token;

  @override
  Future<void> forget(String engineId) async => tokens.remove(engineId);
}
