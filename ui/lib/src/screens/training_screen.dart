import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../games/training.dart';
import '../input/game_input.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final Training _training = Training();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visit = _training.currentVisit;

    final scorePanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${l10n.visit} ${_training.visitNumber}', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 3; ++i)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      i < visit.length ? visit[i].score.label : '–',
                      key: ValueKey('visit-dart-$i'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Stat(l10n.darts, '${_training.dartCount}'),
        _Stat(l10n.points, '${_training.totalPoints}', key: const ValueKey('total-points')),
        _Stat(l10n.average, _training.threeDartAverage.toStringAsFixed(1)),
        const SizedBox(height: 16),
        if (_training.dartCount == 0) Text(l10n.noThrowsYet, style: theme.textTheme.bodyMedium),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _training.dartCount == 0 ? null : () => setState(_training.undo),
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    final input = GameInput(
      game: _training,
      shownThrows: visit,
      onDart: (dart) => setState(() => _training.add(dart)),
      onChanged: () => setState(() {}),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeTraining)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth > constraints.maxHeight
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: input),
                    const SizedBox(width: 24),
                    SizedBox(width: 320, child: scorePanel),
                  ],
                )
              : Column(
                  children: [
                    Expanded(flex: 3, child: input),
                    const SizedBox(height: 16),
                    Expanded(flex: 2, child: scorePanel),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
