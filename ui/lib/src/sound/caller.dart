import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A voice that speaks a text in a language at a volume from 0 to 1
abstract interface class Voice {
  Future<bool> get available;
  Future<void> speak(String text, {required String language, required double volume});
}

/// The platform's text-to-speech: flutter_tts where it has an implementation, speech-dispatcher (`spd-say`) on Linux
class SystemVoice implements Voice {
  FlutterTts? _tts;

  static bool get _linux => !kIsWeb && Platform.isLinux;

  @override
  Future<bool> get available async {
    if (!_linux) return true;
    try {
      return (await Process.run('which', ['spd-say'])).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<void> speak(String text, {required String language, required double volume}) async {
    if (_linux) {
      // spd-say takes the volume from -100 to 100.
      await Process.run('spd-say', ['-l', language, '-i', '${(volume * 200 - 100).round()}', text]);
      return;
    }
    final tts = _tts ??= FlutterTts();
    await tts.setLanguage(language == 'de' ? 'de-DE' : 'en-GB');
    await tts.setVolume(volume);
    await tts.speak(text);
  }
}

/// A voice that only remembers what it was given, for tests
class RecordingVoice implements Voice {
  final List<String> spoken = [];

  @override
  Future<bool> get available async => true;

  @override
  Future<void> speak(String text, {required String language, required double volume}) async => spoken.add(text);
}

/// The score caller (#132): on or off and its own volume, kept on this device
class Caller extends ChangeNotifier {
  Caller(this.voice, {this.store = true});

  final Voice voice;

  /// Whether the settings are kept in the device's preferences; tests keep them in memory
  final bool store;

  bool enabled = false;
  double volume = 0.8;

  static const _enabledKey = 'caller.enabled';
  static const _volumeKey = 'caller.volume';

  Future<void> load() async {
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? false;
    volume = prefs.getDouble(_volumeKey) ?? 0.8;
    notifyListeners();
  }

  Future<void> set({bool? enabled, double? volume}) async {
    this.enabled = enabled ?? this.enabled;
    this.volume = volume ?? this.volume;
    notifyListeners();
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, this.enabled);
    await prefs.setDouble(_volumeKey, this.volume);
  }

  /// Says `calls` one after the other, when the caller is on
  void call(List<String> calls, String language) {
    if (!enabled || calls.isEmpty) return;
    voice.speak(calls.join('. '), language: language, volume: volume);
  }
}

class CallerScope extends InheritedNotifier<Caller> {
  const CallerScope({super.key, required Caller caller, required super.child}) : super(notifier: caller);

  static final Caller _silent = Caller(RecordingVoice(), store: false);

  static Caller of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CallerScope>()?.notifier ?? _silent;

  /// Without rebuilding, for game screens that only call
  static Caller read(BuildContext context) => context.getInheritedWidgetOfExactType<CallerScope>()?.notifier ?? _silent;
}
