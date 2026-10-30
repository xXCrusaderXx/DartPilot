import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../board/dart_throw.dart';
import 'caller.dart';
import 'effects.dart';
import 'x01_calls.dart';

/// The licences of the native audio code flutter_soloud builds into the app (SoLoud and its filters), for the licence
/// page beside the Dart packages
void registerSoundLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/licenses/soloud.txt');
    yield LicenseEntryWithLineBreaks(['SoLoud'], text);
  });
}

/// How strongly a phone vibrates
enum Haptic { light, medium }

/// Where effects are played and felt
abstract interface class EffectOutput {
  /// Whether this device can vibrate under the player's hand: phones and tablets, not desktops or browsers
  bool get canVibrate;

  void play(Effect effect, {required double volume});
  void vibrate(Haptic haptic);
}

/// Effects through SoLoud, vibration through the platform. Where the audio cannot start, the app stays silent.
class SystemEffects implements EffectOutput {
  Future<Map<Effect, AudioSource>?>? _sources;

  @override
  bool get canVibrate =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Starts the audio and loads the sounds, so the first dart is heard at once. Browsers start audio only after a
  /// tap, so there the first effect does this.
  void warmUp() {
    if (!kIsWeb) _load();
  }

  Future<Map<Effect, AudioSource>?> _load() => _sources ??= () async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init();
      return {for (final e in Effect.values) e: await soloud.loadAsset(e.asset)};
    } catch (e) {
      debugPrint('Sound effects are off on this device: $e');
      return null;
    }
  }();

  @override
  void play(Effect effect, {required double volume}) {
    _load().then((sources) {
      final source = sources?[effect];
      if (source == null) return;
      try {
        SoLoud.instance.play(source, volume: volume);
      } catch (e) {
        debugPrint('A sound effect could not play: $e');
      }
    });
  }

  @override
  void vibrate(Haptic haptic) {
    if (!canVibrate) return;
    unawaited(switch (haptic) {
      Haptic.light => HapticFeedback.lightImpact(),
      Haptic.medium => HapticFeedback.mediumImpact(),
    });
  }
}

/// Effects that are only remembered, for tests
class RecordingEffects implements EffectOutput {
  RecordingEffects({this.canVibrate = false});

  @override
  final bool canVibrate;

  final List<(Effect, double)> played = [];
  final List<Haptic> felt = [];

  List<Effect> get effects => [for (final (e, _) in played) e];

  @override
  void play(Effect effect, {required double volume}) => played.add((effect, volume));

  @override
  void vibrate(Haptic haptic) => felt.add(haptic);
}

/// The sound effects and vibration: on or off and the effects' volume, kept on this device
class Sfx extends ChangeNotifier {
  Sfx(this.output, {this.store = true});

  final EffectOutput output;

  /// Whether the settings are kept in the device's preferences; tests keep them in memory
  final bool store;

  bool enabled = true;
  double volume = 0.5;
  bool vibration = true;

  /// A bot's darts are heard, but quieter than the players' own
  static const double botGain = 0.5;

  static const _enabledKey = 'sfx.enabled';
  static const _volumeKey = 'sfx.volume';
  static const _vibrationKey = 'sfx.vibration';

  bool get canVibrate => output.canVibrate;

  Future<void> load() async {
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? true;
    volume = prefs.getDouble(_volumeKey) ?? 0.5;
    vibration = prefs.getBool(_vibrationKey) ?? true;
    notifyListeners();
  }

  /// Changes the settings; [save] false only shows a value while a slider is dragged, and keeps it at its end.
  Future<void> set({bool? enabled, double? volume, bool? vibration, bool save = true}) async {
    this.enabled = enabled ?? this.enabled;
    this.volume = volume ?? this.volume;
    this.vibration = vibration ?? this.vibration;
    notifyListeners();
    if (!store || !save) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, this.enabled);
    await prefs.setDouble(_volumeKey, this.volume);
    await prefs.setBool(_vibrationKey, this.vibration);
  }

  /// Plays `effect` when effects are on, `gain` times their volume; whether it played
  bool play(Effect effect, {double gain = 1}) {
    if (!enabled || volume <= 0) return false;
    output.play(effect, volume: volume * gain);
    return true;
  }

  void vibrate(Haptic haptic) {
    if (vibration && canVibrate) output.vibrate(haptic);
  }
}

class SfxScope extends InheritedNotifier<Sfx> {
  const SfxScope({super.key, required Sfx sfx, required super.child}) : super(notifier: sfx);

  static final Sfx _silent = Sfx(RecordingEffects(), store: false)..enabled = false;

  static Sfx of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SfxScope>()?.notifier ?? _silent;

  /// Without rebuilding, for game screens that only play
  static Sfx read(BuildContext context) => context.getInheritedWidgetOfExactType<SfxScope>()?.notifier ?? _silent;
}

/// How long the caller waits after a dart's thud, so the thud is heard first and the words stay clear of it
const Duration callerDelay = Duration(milliseconds: 150);

/// How long the caller waits after `effect`: past the thud of a dart, and past most of the longer sounds, so the
/// voice does not talk over the chord of a leg or the match (0.9 s and 1.3 s long) or the falling notes of a bust.
/// Their last notes fade out under the first word.
Duration callerDelayAfter(Effect effect) => switch (effect) {
  Effect.match => const Duration(milliseconds: 1100),
  Effect.leg => const Duration(milliseconds: 750),
  Effect.bust => const Duration(milliseconds: 400),
  _ => callerDelay,
};

/// What follows a dart of a game: its one sound, a vibration for a dart entered by hand on a phone, and the caller's
/// `calls`. The caller has priority: what it says in words (the end of a visit, a 180) is not also played as an effect;
/// the dart's own thud plays instead. A bot's darts are heard quieter and are not felt.
void dartFeedback(
  BuildContext context,
  DartThrow dart, {
  required Effect effect,
  List<String> calls = const [],
  bool bot = false,
}) {
  final sfx = SfxScope.read(context);
  final caller = CallerScope.read(context);
  final speaks = caller.enabled && calls.isNotEmpty;
  final sound = speaks && effect.saidByCaller ? dartEffect(dart) : effect;
  final played = sfx.play(sound, gain: bot && sound.perDart ? Sfx.botGain : 1);
  if (!bot && dart.input != ThrowInput.engine) sfx.vibrate(sound.strong ? Haptic.medium : Haptic.light);
  if (!speaks) return;
  if (played) {
    Timer(callerDelayAfter(sound), () => caller.call(calls, callLanguage));
  } else {
    caller.call(calls, callLanguage);
  }
}
