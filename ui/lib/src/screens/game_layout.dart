import 'package:flutter/material.dart';

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
                  SizedBox(width: panelWidth, child: panel),
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

/// The darts of the current visit as three cards
class VisitDarts extends StatelessWidget {
  const VisitDarts(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge;
    return Row(
      children: [
        for (var i = 0; i < 3; ++i)
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  i < labels.length ? labels[i] : '–',
                  key: ValueKey('visit-dart-$i'),
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
