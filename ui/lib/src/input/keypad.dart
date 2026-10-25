import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../board/scoring.dart';

/// Classic score keypad: choose single, double or triple, then the number. Each entry becomes a board point in the
/// middle of the chosen field, so the score comes from the same scorer as board taps.
class Keypad extends StatefulWidget {
  const Keypad({super.key, required this.onThrow, this.geometry = const BoardGeometry(), this.maxHeight});

  final ValueChanged<DartThrow> onThrow;
  final BoardGeometry geometry;

  /// Height the keypad should fit into; its keys get flatter down to [minKeyHeight] before it needs scrolling
  final double? maxHeight;

  static const double minKeyHeight = 36;

  @override
  State<Keypad> createState() => _KeypadState();
}

class _KeypadState extends State<Keypad> {
  Ring _modifier = Ring.innerSingle;

  void _emit(Ring ring, {int sector = 20}) {
    widget.onThrow(
      DartThrow(
        fieldCentre(ring, sector: sector, geometry: widget.geometry),
        ThrowInput.keypad,
        geometry: widget.geometry,
      ),
    );
    setState(() => _modifier = Ring.innerSingle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget modifier(Ring ring, String text) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ChoiceChip(
          label: SizedBox(
            width: double.infinity,
            child: Text(text, textAlign: TextAlign.center),
          ),
          selected: _modifier == ring,
          onSelected: (_) => setState(() => _modifier = ring),
        ),
      ),
    );
    Widget key(String text, VoidCallback onPressed, {Key? key}) => Padding(
      padding: const EdgeInsets.all(3),
      child: FilledButton.tonal(key: key, onPressed: onPressed, child: Text(text)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Five rows of keys share what is left below the modifiers: four of numbers and one of bull and miss.
        final keyWidth = constraints.maxWidth / 5;
        var keyHeight = keyWidth / 1.6;
        final maxHeight = widget.maxHeight;
        if (maxHeight != null && maxHeight.isFinite) {
          keyHeight = keyHeight.clamp(Keypad.minKeyHeight, math.max(Keypad.minKeyHeight, (maxHeight - 48) / 5));
        }
        return _layout(modifier, key, keyWidth / keyHeight, keyHeight, l10n);
      },
    );
  }

  Widget _layout(
    Widget Function(Ring, String) modifier,
    Widget Function(String, VoidCallback, {Key? key}) key,
    double aspectRatio,
    double keyHeight,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            modifier(Ring.innerSingle, l10n.single),
            modifier(Ring.double, l10n.double),
            modifier(Ring.triple, l10n.triple),
          ],
        ),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          childAspectRatio: aspectRatio,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var n = 1; n <= 20; ++n) key('$n', () => _emit(_modifier, sector: n), key: ValueKey('keypad-$n')),
          ],
        ),
        SizedBox(
          height: keyHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: key('25', () => _emit(Ring.outerBull), key: const ValueKey('keypad-25'))),
              Expanded(child: key('Bull', () => _emit(Ring.innerBull), key: const ValueKey('keypad-bull'))),
              Expanded(child: key(l10n.miss, () => _emit(Ring.miss), key: const ValueKey('keypad-miss'))),
            ],
          ),
        ),
      ],
    );
  }
}
