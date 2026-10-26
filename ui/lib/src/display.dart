import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much room the window gives, by its width: a phone upright, a phone on its side or a tablet, a monitor or TV.
/// Layouts change at these widths and nowhere else.
enum WindowClass {
  compact,
  medium,
  large;

  static const double mediumFrom = 600;
  static const double largeFrom = 1200;

  static WindowClass forWidth(double width) => width >= largeFrom
      ? large
      : width >= mediumFrom
      ? medium
      : compact;

  static WindowClass of(BuildContext context) => forWidth(MediaQuery.sizeOf(context).width);
}

/// How a game is shown: clear and large in the app's own colours, or as a TV scoreboard that fits more on less room
enum DisplayStyle { auto, clear, scoreboard }

/// Whether the screen is read from close by (in the hand, on the desk) or from the oche (at the board, a TV)
enum ViewingDistance { auto, near, far }

/// The player's choice of display style and viewing distance for this device; auto picks by the window.
class DisplaySettings extends ChangeNotifier {
  DisplaySettings({this.store = true});

  /// Whether the choice is kept in the device's preferences; tests keep it in memory
  final bool store;

  DisplayStyle style = DisplayStyle.auto;
  ViewingDistance distance = ViewingDistance.auto;

  static const _styleKey = 'display.style';
  static const _distanceKey = 'display.distance';

  Future<void> load() async {
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    style = DisplayStyle.values.asNameMap()[prefs.getString(_styleKey)] ?? DisplayStyle.auto;
    distance = ViewingDistance.values.asNameMap()[prefs.getString(_distanceKey)] ?? ViewingDistance.auto;
    notifyListeners();
  }

  Future<void> set({DisplayStyle? style, ViewingDistance? distance}) async {
    this.style = style ?? this.style;
    this.distance = distance ?? this.distance;
    notifyListeners();
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, this.style.name);
    await prefs.setString(_distanceKey, this.distance.name);
  }

  /// The style a game uses in this window: on a phone the scoreboard fits more, elsewhere the clear style
  DisplayStyle styleFor(WindowClass window) => style != DisplayStyle.auto
      ? style
      : window == WindowClass.compact
      ? DisplayStyle.scoreboard
      : DisplayStyle.clear;

  /// Read from the oche: on a monitor or TV by default, in the hand or on a tablet from close by
  bool farFor(WindowClass window) =>
      distance == ViewingDistance.auto ? window == WindowClass.large : distance == ViewingDistance.far;
}

class DisplayScope extends InheritedNotifier<DisplaySettings> {
  const DisplayScope({super.key, required DisplaySettings settings, required super.child}) : super(notifier: settings);

  static final DisplaySettings _defaults = DisplaySettings(store: false);

  static DisplaySettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DisplayScope>()?.notifier ?? _defaults;
}

/// A motion's duration, or none where the system asks for less motion
Duration motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
