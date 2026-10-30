import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../games/training.dart';
import '../input/game_input.dart';
import '../input/takeout_gate.dart';
import '../board/score_text.dart';
import '../widgets/player_row.dart';
import '../widgets/precision_text.dart';
import 'game_layout.dart';

/// Free throwing to warm up: the visit's total large, the running figures below it. Nothing is kept, and the screen
/// says so, so a player who wants the darts in the statistics picks X01 or a training.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final Training _training = Training();
  final TakeoutGate _takeout = TakeoutGate();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visit = _training.currentVisit;
    final visitTotal = visit.fold(0, (sum, t) => sum + t.score.points);

    final panel = ScrollingPanel(
      top: [
        PlayerRow(
          name: '${l10n.visit} ${_training.visitNumber}',
          value: '$visitTotal',
          valueKey: const ValueKey('visit-total'),
          details: [
            l10n.labelValue(l10n.darts, '${_training.dartCount}'),
            l10n.labelValue(l10n.points, '${_training.totalPoints}'),
            l10n.labelValue(l10n.average, decimal(l10n, _training.threeDartAverage)),
          ].join('  ·  '),
          detailsKey: const ValueKey('total-points'),
          detailsFromAfar: true,
          active: true,
        ),
        VisitDarts([for (final t in visit) t.score.text(l10n)]),
        const SizedBox(height: 12),
        if (_training.dartCount == 0) Text(l10n.noThrowsYet, style: theme.textTheme.bodyMedium),
        Text(l10n.trainingNotKept, key: const ValueKey('training-not-kept'), style: theme.textTheme.bodySmall),
      ],
      bottom: [
        OutlinedButton.icon(
          onPressed: _training.dartCount == 0 ? null : () => setState(_training.undo),
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    final input = GameInput(
      takeout: _takeout,
      game: _training,
      shownThrows: visit,
      onDart: (dart) => setState(() => _training.add(dart)),
      onChanged: () => setState(() {}),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeTraining)),
      body: SafeArea(
        child: GameLayout(input: input, panel: panel),
      ),
    );
  }
}
