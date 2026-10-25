import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Named sets of detection values, stored on this device, to return to a setting that worked
class ParamProfiles {
  static const _key = 'detection.profiles';

  static Future<Map<String, Map<String, double>>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    final json = raw == null ? null : jsonDecode(raw);
    if (json is! Map<String, dynamic>) return {};
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (value is Map<String, dynamic>)
          key: {
            for (final p in value.entries)
              if (p.value is num) p.key: (p.value as num).toDouble(),
          },
    };
  }

  static Future<void> save(String name, Map<String, double> params) async {
    final profiles = await load()
      ..[name] = params;
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(profiles));
  }

  static Future<void> delete(String name) async {
    final profiles = await load()
      ..remove(name);
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(profiles));
  }
}
