import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../board/dart_throw.dart';
import '../board/dartboard.dart';
import '../board/scoring.dart';
import 'keypad.dart';

/// Manual input until the engine is connected: the dartboard or the keypad, switchable; the caller keeps which.
class ThrowInputPanel extends StatelessWidget {
  const ThrowInputPanel({
    super.key,
    required this.onThrow,
    required this.keypad,
    required this.onKeypadChanged,
    this.shownThrows = const [],
    this.highlights = const [],
    this.geometry = const BoardGeometry(),
  });

  final ValueChanged<DartThrow> onThrow;
  final bool keypad;
  final ValueChanged<bool> onKeypadChanged;

  /// Throws to mark on the board, e.g. the current visit
  final List<DartThrow> shownThrows;

  /// Fields to mark on the board, e.g. the fields an uncertain dart may be in
  final List<Score> highlights;
  final BoardGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Two words that must not break inside: with the largest text they stay at a size that fits
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.adjust),
                label: Text(l10n.inputBoard, softWrap: false),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.dialpad),
                label: Text(l10n.inputKeypad, softWrap: false),
              ),
            ],
            selected: {keypad},
            onSelectionChanged: (selection) => onKeypadChanged(selection.first),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: keypad
                ? LayoutBuilder(
                    // Fits the space it has; scrolls only where its keys would get too small to hit
                    builder: (context, constraints) => SingleChildScrollView(
                      child: Keypad(onThrow: onThrow, geometry: geometry, maxHeight: constraints.maxHeight),
                    ),
                  )
                : EngineSelect(
                    select: (engine) => engine.boardImage,
                    builder: (context, image) => Dartboard(
                      key: const ValueKey('dartboard'),
                      geometry: geometry,
                      throws: shownThrows,
                      highlights: highlights,
                      image: image,
                      onTap: (point) => onThrow(DartThrow(point, ThrowInput.board, geometry: geometry)),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
