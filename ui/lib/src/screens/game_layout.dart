import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../display.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Input and score panel side by side in landscape, the board on the side the player chose; stacked in portrait. The
/// player's board size moves the line between them, while the panel keeps at least [panelWidth].
class GameLayout extends StatelessWidget {
  const GameLayout({super.key, required this.input, required this.panel, this.panelWidth = 340});

  final Widget input;
  final Widget panel;
  final double panelWidth;

  /// The panel's width in a row of [width]: on a monitor or TV the score takes about half the room by default, and the
  /// board keeps the rest.
  double _panelWidthIn(double width, BoardSize size) => switch (size) {
    BoardSize.large => panelWidth,
    BoardSize.medium => width >= WindowClass.largeFrom ? math.max(panelWidth, width * 0.42) : panelWidth,
    BoardSize.small => math.max(panelWidth, width * (width >= WindowClass.largeFrom ? 0.55 : 0.5)),
  };

  @override
  Widget build(BuildContext context) {
    final display = DisplayScope.of(context);
    final (inputFlex, panelFlex) = switch (display.boardSize) {
      BoardSize.large => (4, 3),
      BoardSize.medium => (3, 3),
      BoardSize.small => (2, 3),
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= constraints.maxHeight) {
            return Column(
              children: [
                Expanded(flex: inputFlex, child: input),
                const SizedBox(height: 16),
                Expanded(flex: panelFlex, child: panel),
              ],
            );
          }
          final board = Expanded(child: input);
          final side = SizedBox(width: _panelWidthIn(constraints.maxWidth, display.boardSize), child: panel);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: display.boardSide == BoardSide.left
                ? [board, const SizedBox(width: 24), side]
                : [side, const SizedBox(width: 24), board],
          );
        },
      ),
    );
  }
}

/// A score panel: [top] from the top and [bottom], such as Undo, always at its foot, the top scrolling when it does not
/// fit; a panel too short even for that scrolls as one.
class ScrollingPanel extends StatelessWidget {
  const ScrollingPanel({super.key, required this.top, this.bottom = const []});

  final List<Widget> top;
  final List<Widget> bottom;

  /// Below this height the top would have no room left above the bottom
  static const double pinnedFrom = 240;

  @override
  Widget build(BuildContext context) {
    final topColumn = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: top);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (bottom.isNotEmpty && constraints.maxHeight >= pinnedFrom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SingleChildScrollView(child: topColumn)),
              const SizedBox(height: 12),
              ...bottom,
            ],
          );
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                topColumn,
                if (bottom.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bottom),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The darts of the current visit as three cards
class VisitDarts extends StatelessWidget {
  const VisitDarts(this.labels, {super.key, this.hits});

  final List<String> labels;

  /// Whether each dart hit its target, in games that have one; shown as a tick or a cross beside the dart
  final List<bool>? hits;

  @override
  Widget build(BuildContext context) {
    final style = scoreStyle(Theme.of(context).textTheme.headlineSmall)?.copyWith(fontWeight: FontWeight.w600);
    final l10n = AppLocalizations.of(context);
    final colours = StatusColors.of(context);
    final hits = this.hits;
    if (!DisplayScope.of(context).shows(PanelDetail.visitDarts)) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < 3; ++i)
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // A narrow card shrinks a long label such as D-Bull rather than cutting it.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          i < labels.length ? labels[i] : '–',
                          key: ValueKey('visit-dart-$i'),
                          textAlign: TextAlign.center,
                          style: style,
                        ),
                      ),
                    ),
                    if (hits != null && i < hits.length) ...[
                      const SizedBox(width: 6),
                      Icon(
                        hits[i] ? Icons.check : Icons.close,
                        key: ValueKey('visit-hit-$i'),
                        color: hits[i] ? colours.good : colours.bad,
                        semanticLabel: hits[i] ? l10n.visitHit : l10n.visitNoHit,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
