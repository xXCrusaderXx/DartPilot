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

  /// The modifier row is this part of a key row's height.
  static const double _modifierShare = 0.75;

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

  /// The key height for `columns` keys per row and `rows` rows below the modifiers: as wide keys allow, flatter when
  /// the height is short, never below [Keypad.minKeyHeight].
  double _keyHeight(double width, int columns, int rows) {
    var keyHeight = width / columns / 1.6;
    final maxHeight = widget.maxHeight;
    if (maxHeight != null && maxHeight.isFinite) {
      keyHeight = math.min(keyHeight, maxHeight / (rows + _modifierShare));
    }
    return math.max(Keypad.minKeyHeight, keyHeight);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Five keys a row, with bull and miss in a row of their own; where the height is short, as on a phone in
        // landscape, six a row with bull and miss after 19 and 20, so all keys fit without scrolling.
        final width = constraints.maxWidth;
        final regular = _keyHeight(width, 5, 5);
        final compact = _keyHeight(width, 6, 4);
        final dense = compact > regular + 1;
        final keyHeight = dense ? compact : regular;
        // Labels grow with the keys, so they read from the oche on a tablet or TV.
        final fontSize = (keyHeight * 0.38).clamp(14.0, 40.0);
        final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(math.min(12, keyHeight / 4)));
        final prefix = switch (_modifier) {
          Ring.double => 'D',
          Ring.triple => 'T',
          _ => '',
        };

        Widget cell(Widget child, {int flex = 1}) => Expanded(
          flex: flex,
          child: Padding(padding: const EdgeInsets.all(3), child: child),
        );
        Widget key(String text, VoidCallback onPressed, {required Key key, int flex = 1}) => cell(
          flex: flex,
          FilledButton.tonal(
            key: key,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              shape: shape,
              padding: EdgeInsets.zero,
              // A calm ripple: the Material sparkle is noisy on keys tapped dozens of times a game.
              splashFactory: InkRipple.splashFactory,
              textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1)),
          ),
        );
        Widget modifier(Ring ring, String text) {
          final selected = _modifier == ring;
          return cell(
            FilledButton(
              key: ValueKey('keypad-modifier-${ring.name}'),
              onPressed: () => setState(() => _modifier = ring),
              style: FilledButton.styleFrom(
                shape: shape,
                padding: EdgeInsets.zero,
                splashFactory: InkRipple.splashFactory,
                backgroundColor: selected ? scheme.primary : scheme.surfaceContainerHighest,
                foregroundColor: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: fontSize * 0.8, fontWeight: FontWeight.w600),
              ),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1)),
            ),
          );
        }

        Widget number(int n) => key('$prefix$n', () => _emit(_modifier, sector: n), key: ValueKey('keypad-$n'));
        final outerBull = key('25', () => _emit(Ring.outerBull), key: const ValueKey('keypad-25'));
        final bull = key('Bull', () => _emit(Ring.innerBull), key: const ValueKey('keypad-bull'));
        Widget miss({int flex = 1}) =>
            key(l10n.miss, () => _emit(Ring.miss), key: const ValueKey('keypad-miss'), flex: flex);
        Widget row(List<Widget> keys, {double? height}) => SizedBox(
          height: height ?? keyHeight,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: keys),
        );

        final columns = dense ? 6 : 5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(height: keyHeight * _modifierShare, [
              modifier(Ring.innerSingle, l10n.single),
              modifier(Ring.double, l10n.double),
              modifier(Ring.triple, l10n.triple),
            ]),
            for (var first = 1; first <= (dense ? 13 : 16); first += columns)
              row([for (var n = first; n < first + columns; ++n) number(n)]),
            if (dense)
              row([number(19), number(20), outerBull, bull, miss(flex: 2)])
            else
              row([outerBull, bull, miss()]),
          ],
        );
      },
    );
  }
}
