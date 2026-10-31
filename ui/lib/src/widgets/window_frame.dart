import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// On Linux and Windows the app draws its own slim title bar in its colours, in place of the system's thick one.
class WindowFrame {
  /// Set once the system's title bar is hidden; tests and other platforms keep the plain layout
  static bool enabled = false;

  static bool get supported => !kIsWeb && (Platform.isLinux || Platform.isWindows);

  /// Hides the system's title bar; where that fails the window keeps it and the app draws none.
  static Future<void> setUp() async {
    if (!supported) return;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
      enabled = true;
    } catch (e) {
      debugPrint('The window keeps the system title bar: $e');
    }
  }
}

/// Drag to move, double-click to maximise, and the window's three buttons
class TitleBar extends StatefulWidget {
  const TitleBar({super.key});

  static const double height = 32;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((maximized) {
      if (mounted) setState(() => _maximized = maximized);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggleMaximized() async => _maximized ? windowManager.unmaximize() : windowManager.maximize();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return Material(
      color: palette.sidebar,
      child: SizedBox(
        height: TitleBar.height,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: _toggleMaximized,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: palette.textMuted),
                    ),
                  ),
                ),
              ),
            ),
            _WindowButton(
              key: const ValueKey('window-minimize'),
              icon: Icons.remove,
              tooltip: l10n.windowMinimize,
              onPressed: windowManager.minimize,
            ),
            _WindowButton(
              key: const ValueKey('window-maximize'),
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _maximized ? l10n.windowRestore : l10n.windowMaximize,
              onPressed: _toggleMaximized,
            ),
            _WindowButton(
              key: const ValueKey('window-close'),
              icon: Icons.close,
              tooltip: l10n.windowClose,
              onPressed: windowManager.close,
              hoverColour: palette.bad,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.hoverColour,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? hoverColour;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // A label for screen readers; the builder above the navigator has no overlay a tooltip could show in
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onPressed,
        hoverColor: hoverColour ?? palette.surfaceRaised,
        child: SizedBox(
          width: 46,
          height: TitleBar.height,
          child: Icon(icon, size: 16, color: palette.textMuted),
        ),
      ),
    );
  }
}
