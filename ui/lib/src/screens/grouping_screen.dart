import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/dart_game.dart';
import '../games/grouping.dart';
import '../input/game_input.dart';
import '../input/takeout_gate.dart';
import '../stats/game_record.dart';
import '../stats/precision.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import '../widgets/precision_plot.dart';
import '../widgets/precision_text.dart';
import 'game_layout.dart';
import 'my_darts_screen.dart';
import 'watched_board.dart';
import '../widgets/leave_game_guard.dart';

/// Grouping training (#125): darts at one target, with the miss of every dart and the group's spread in mm.
class GroupingScreen extends StatefulWidget {
  const GroupingScreen({
    super.key,
    required this.player,
    required this.target,
    this.dartCount = 9,
    this.replay = const [],
    this.watching = false,
  });

  final String player;
  final PrecisionTarget target;
  final int dartCount;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static Widget setup(BuildContext context) => const GroupingSetupScreen();

  @override
  State<GroupingScreen> createState() => _GroupingScreenState();
}

class _GroupingScreenState extends State<GroupingScreen> with RecordsGame {
  @override
  bool get watching => widget.watching;

  late final GroupingGame _game = replayed(GroupingGame(widget.target, dartCount: widget.dartCount), widget.replay);
  final TakeoutGate _takeout = TakeoutGate();

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.grouping,
    started: started,
    ended: ended,
    players: [widget.player],
    settings: {'target': widget.target.label, 'darts': widget.dartCount},
    throws: _game.throws,
  );

  void _add(DartThrow dart) {
    setState(() => _game.add(dart));
    if (_game.isFinished) _showResult();
  }

  Future<void> _showResult() {
    final l10n = AppLocalizations.of(context);
    final spread = _game.spread;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.groupingDone),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.precisionSpread}: ${spread == null ? '–' : mmText(l10n, spread.spreadMm)}',
              key: const ValueKey('grouping-result-spread'),
            ),
            if (spread != null)
              Text('${l10n.precisionOffset}: ${offsetText(l10n, spread.offsetXMm, spread.offsetYMm)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(_game.undo);
            },
            child: Text(l10n.undo),
          ),
          TextButton(
            key: const ValueKey('grouping-again'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      GroupingScreen(player: widget.player, target: widget.target, dartCount: widget.dartCount),
                ),
              );
            },
            child: Text(l10n.groupingAgain),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: Text(l10n.backToMenu),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.watching) return;
      shareGame();
      if (mounted && !_game.isFinished) useDartsOf(context, widget.player);
    });
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final throws = _game.throws;
    final spread = _game.spread;
    final unmeasured = throws.length - _game.measured.length;

    final panel = ListView(
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.player, style: theme.textTheme.titleMedium)),
            Text(widget.target.label, key: const ValueKey('grouping-target'), style: theme.textTheme.displaySmall),
          ],
        ),
        Text(
          l10n.groupingProgress((throws.length + 1).clamp(1, widget.dartCount), widget.dartCount),
          key: const ValueKey('grouping-progress'),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: PrecisionPlot(
              key: const ValueKey('grouping-plot'),
              target: widget.target,
              points: [for (final t in _game.measured) t.point],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.precisionSpread),
          trailing: Text(
            spread == null ? '–' : mmText(l10n, spread.spreadMm),
            key: const ValueKey('grouping-spread'),
            style: theme.textTheme.titleLarge,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.precisionOffset),
          trailing: Text(spread == null ? '–' : offsetText(l10n, spread.offsetXMm, spread.offsetYMm)),
        ),
        if (unmeasured > 0) Text(l10n.groupingNotMeasured, style: theme.textTheme.bodySmall),
        for (var i = throws.length - 1; i >= 0; --i)
          MissTile(key: ValueKey('grouping-dart-$i'), number: i + 1, dart: throws[i], target: widget.target),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: throws.isEmpty || widget.watching ? null : () => setState(_game.undo),
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    return LeaveGameGuard(
      canLeave: widget.watching || _game.isFinished || currentRecord.throws.isEmpty,
      child: Scaffold(
        appBar: AppBar(title: Text('${l10n.modeGrouping} ${widget.target.label}')),
        body: GameLayout(
          input: widget.watching
              ? WatchedBoard(throws: throws)
              : GameInput(
                  game: _game,
                  takeout: _takeout,
                  shownThrows: throws,
                  onDart: _add,
                  onChanged: () => setState(() {}),
                ),
          panel: panel,
        ),
      ),
    );
  }
}

/// Who throws, at which target, and how many darts
class GroupingSetupScreen extends StatefulWidget {
  const GroupingSetupScreen({super.key});

  @override
  State<GroupingSetupScreen> createState() => _GroupingSetupScreenState();
}

class _GroupingSetupScreenState extends State<GroupingSetupScreen> {
  String? _player;
  PrecisionTarget _target = trainingTargets.first;
  int _dartCount = 9;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profiles = StatisticsScope.maybeOf(context)?.players ?? const <String>[];
    final player = _player ?? profiles.firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeGrouping)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProfileChoice(selected: player, onSelected: (name) => setState(() => _player = name)),
              const SizedBox(height: 24),
              Text(l10n.groupingTarget, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in trainingTargets)
                    ChoiceChip(
                      key: ValueKey('target-${target.label}'),
                      label: Text(target.label),
                      selected: target == _target,
                      onSelected: (_) => setState(() => _target = target),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.groupingDartCount, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final n in const [9, 15, 30]) ButtonSegment(value: n, label: Text('$n')),
                ],
                selected: {_dartCount},
                onSelectionChanged: (s) => setState(() => _dartCount = s.first),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('start-game'),
                onPressed: player == null
                    ? null
                    : () async {
                        if (!await confirmBoardEmpty(context) || !context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => GroupingScreen(player: player, target: _target, dartCount: _dartCount),
                          ),
                        );
                      },
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
