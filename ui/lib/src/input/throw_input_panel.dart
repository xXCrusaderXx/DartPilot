import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../board/dart_throw.dart';
import '../board/dartboard.dart';
import '../board/scoring.dart';
import 'keypad.dart';

/// Manual input until the engine is connected: the dartboard or the keypad, switchable.
class ThrowInputPanel extends StatefulWidget {
  const ThrowInputPanel({
    super.key,
    required this.onThrow,
    this.shownThrows = const [],
    this.geometry = const BoardGeometry(),
  });

  final ValueChanged<DartThrow> onThrow;

  /// Throws to mark on the board, e.g. the current visit
  final List<DartThrow> shownThrows;
  final BoardGeometry geometry;

  @override
  State<ThrowInputPanel> createState() => _ThrowInputPanelState();
}

class _ThrowInputPanelState extends State<ThrowInputPanel> {
  bool _keypad = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, icon: const Icon(Icons.adjust), label: Text(l10n.inputBoard)),
            ButtonSegment(value: true, icon: const Icon(Icons.dialpad), label: Text(l10n.inputKeypad)),
          ],
          selected: {_keypad},
          onSelectionChanged: (selection) => setState(() => _keypad = selection.first),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: _keypad
                ? LayoutBuilder(
                    // Fits the space it has; scrolls only where its keys would get too small to hit
                    builder: (context, constraints) => SingleChildScrollView(
                      child: Keypad(
                        onThrow: widget.onThrow,
                        geometry: widget.geometry,
                        maxHeight: constraints.maxHeight,
                      ),
                    ),
                  )
                : Dartboard(
                    key: const ValueKey('dartboard'),
                    geometry: widget.geometry,
                    throws: widget.shownThrows,
                    image: EngineScope.of(context).boardImage,
                    onTap: (point) => widget.onThrow(DartThrow(point, ThrowInput.board, geometry: widget.geometry)),
                  ),
          ),
        ),
      ],
    );
  }
}
