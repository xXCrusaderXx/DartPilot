import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../display.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Input on the left and the score panel on the right in landscape; stacked in portrait.
class GameLayout extends StatelessWidget {
  const GameLayout({super.key, required this.input, required this.panel, this.panelWidth = 340});

  final Widget input;
  final Widget panel;
  final double panelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth > constraints.maxHeight
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: input),
                  const SizedBox(width: 24),
                  // On a monitor or TV the score takes about half the room, and the board keeps the rest.
                  SizedBox(
                    width: constraints.maxWidth >= WindowClass.largeFrom
                        ? math.max(panelWidth, constraints.maxWidth * 0.42)
                        : panelWidth,
                    child: panel,
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 3, child: input),
                  const SizedBox(height: 16),
                  Expanded(flex: 3, child: panel),
                ],
              ),
      ),
    );
  }
}

/// A score panel: [top] from the top, [bottom] at its foot when there is room; the whole panel scrolls when there is not
class ScrollingPanel extends StatelessWidget {
  const ScrollingPanel({super.key, required this.top, this.bottom = const []});

  final List<Widget> top;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: top),
              if (bottom.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bottom),
              ],
            ],
          ),
        ),
      ),
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
    final style = Theme.of(context).textTheme.titleLarge;
    final l10n = AppLocalizations.of(context);
    final colours = StatusColors.of(context);
    final hits = this.hits;
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
                    Text(
                      i < labels.length ? labels[i] : '–',
                      key: ValueKey('visit-dart-$i'),
                      textAlign: TextAlign.center,
                      style: style,
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
