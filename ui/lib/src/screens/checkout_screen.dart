import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sound/effects.dart';
import '../sound/sfx.dart';
import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/checkout_trainer.dart';
import '../games/dart_game.dart';
import '../games/x01.dart';
import '../input/takeout_gate.dart';
import '../stats/game_record.dart';
import '../stats/precision.dart';
import '../stats/statistics.dart';
import '../stats/training_best.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import '../widgets/precision_plot.dart';
import '../widgets/precision_text.dart';
import 'game_layout.dart';
import '../widgets/player_row.dart';
import 'game_scaffold.dart';
import 'my_darts_screen.dart';
import '../widgets/winner_dialog.dart';

/// Checkout trainer (#125): random finishes, the field to aim at before every dart, and how far each dart missed it.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.player,
    required this.starts,
    this.dartsPerAttempt = 9,
    this.ladder = false,
    this.replay = const [],
    this.watching = false,
  });

  final String player;

  /// The scores to check out, in order
  final List<int> starts;
  final int dartsPerAttempt;

  /// 121: each checkout made moves up by one
  final bool ladder;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static Widget setup(BuildContext context) => const CheckoutSetupScreen();

  static Widget ladderSetup(BuildContext context) => const CheckoutSetupScreen(ladder: true);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with RecordsGame {
  @override
  bool get watching => widget.watching;

  late final CheckoutTrainer _game = replayed(
    CheckoutTrainer(widget.starts, dartsPerAttempt: widget.dartsPerAttempt, ladder: widget.ladder),
    widget.replay,
  );
  final TakeoutGate _takeout = TakeoutGate();

  List<GameRecord>? _comparedGames;
  TrainingComparison? _comparison;

  /// The player's earlier rounds of this training as kept now: the round played just before is kept only after this
  /// screen opened, when its screen is gone
  TrainingComparison? _earlier(List<GameRecord> games) {
    if (watching) return null;
    if (!identical(games, _comparedGames)) {
      _comparedGames = games;
      _comparison = compareWithEarlier(games, currentRecord, widget.player);
    }
    return _comparison;
  }

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.checkout,
    started: started,
    ended: ended,
    players: [widget.player],
    settings: {'starts': widget.starts, 'darts': widget.dartsPerAttempt, if (widget.ladder) 'ladder': true},
    throws: _game.throws,
  );

  void _add(DartThrow dart) {
    setState(() => _game.add(dart));
    dartFeedback(context, dart, effect: gameEffect(dart, finished: _game.isFinished, training: true));
    if (_game.isFinished) _showResult();
  }

  Future<void> _showResult() {
    final l10n = AppLocalizations.of(context);
    final earlier = _earlier(StatisticsScope.read(context)?.games ?? const []);
    final score = trainingScore(currentRecord);
    return showRoundResult(
      context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              l10n.resultCheckouts(_game.checkouts, _game.attemptsDone),
              if (widget.ladder) l10n.ladderBest(_game.bestCheckout?.toString() ?? '–'),
            ].join('\n'),
            key: const ValueKey('checkout-result'),
          ),
          if (earlier != null && score != null) ...[
            const SizedBox(height: 8),
            PersonalBestLine(
              comparison: earlier,
              value: score.value,
              format: (v) => widget.ladder ? v.toStringAsFixed(0) : percentText(l10n, v),
            ),
          ],
        ],
      ),
      onUndo: () => setState(_game.undo),
      again: (_) => CheckoutScreen(
        player: widget.player,
        starts: checkoutStarts(
          math.Random().nextInt(1 << 31),
          widget.starts.length,
          widget.ladder ? CheckoutRange.ladder : CheckoutRange.of(widget.starts.first),
        ),
        dartsPerAttempt: widget.dartsPerAttempt,
        ladder: widget.ladder,
      ),
    );
  }

  /// What the panel says about the round: the level and the record on the ladder, else the checkouts made
  String _progress(AppLocalizations l10n) {
    final attempt = l10n.attemptOf(_game.attempts.length, widget.starts.length);
    if (!widget.ladder) {
      return '${l10n.checkoutProgress(_game.attempts.length, widget.starts.length)}  ·  '
          '${l10n.labelValue(l10n.statsCheckoutRate, l10n.countOf(_game.checkouts, _game.attemptsDone))}';
    }
    // Read so the panel follows the statistics: the round played just before is kept while this one is played.
    final earlier = _earlier(StatisticsScope.maybeOf(context)?.games ?? const [])?.best.round();
    final now = _game.bestCheckout;
    final record = earlier == null ? now : (now == null ? earlier : math.max(earlier, now));
    return [
      l10n.ladderLevel(_game.current.start),
      attempt,
      if (record != null) l10n.ladderRecord('$record'),
    ].join('  ·  ');
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
    final attempt = _game.current;
    // The checkout just played stays on show until the first dart at the next one.
    final shownIndex = attempt.darts.isEmpty && _game.attempts.length > 1
        ? _game.attempts.length - 2
        : _game.attempts.length - 1;
    final shown = _game.attempts[shownIndex];
    final firstDart = _game.attempts.take(shownIndex).fold(0, (sum, a) => sum + a.darts.length);
    final lastDart = shown.darts.isEmpty ? null : shown.darts.last;
    final lastAim = shown.aims.isEmpty ? null : PrecisionTarget.parse(shown.aims.last);
    final route = _game.isFinished ? null : suggestCheckout(attempt.remaining, 3 - _game.dartsInVisit) ?? [_game.aim];
    final far = readFromAfar(context);
    final unmeasured = _game.throws.any((t) => !hasMeasuredPoint(t));
    // From the oche only the last darts' misses are listed; the plot shows the newest.
    final listed = far ? math.min(3, shown.darts.length) : shown.darts.length;

    final panel = ScrollingPanel(
      top: [
        PlayerRow(
          name: widget.player,
          value: '${_game.isFinished ? 0 : attempt.remaining}',
          valueKey: const ValueKey('checkout-remaining'),
          details: _progress(l10n),
          detailsKey: const ValueKey('checkout-progress'),
          detailsFromAfar: true,
          active: true,
        ),
        if (route != null)
          AimLine(field: route.first, rest: route.skip(1).toList(), fieldKey: const ValueKey('checkout-aim')),
        const SizedBox(height: 12),
        if (lastDart != null && lastAim != null && hasMeasuredPoint(lastDart))
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: PrecisionPlot(key: const ValueKey('checkout-plot'), target: lastAim, points: [lastDart.point]),
            ),
          ),
        if (shown != attempt)
          Text(
            '${shown.start}: ${shown.checkedOut ? l10n.checkoutHit : (shown.busted ? '${l10n.checkoutMissed} (${l10n.bust})' : l10n.checkoutMissed)}',
            key: const ValueKey('checkout-last-result'),
            style: far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium,
          ),
        for (var i = shown.darts.length - 1; i >= shown.darts.length - listed; --i)
          MissTile(
            key: ValueKey('checkout-dart-${firstDart + i}'),
            number: i + 1,
            dart: shown.darts[i],
            target: PrecisionTarget.parse(shown.aims[i]),
            showTarget: true,
          ),
        if (unmeasured && !far) ...[
          const SizedBox(height: 8),
          Text(l10n.precisionNeedsPoints, style: theme.textTheme.bodySmall),
        ],
      ],
      bottom: [GameUndoButton(onPressed: _game.throws.isEmpty || widget.watching ? null : () => setState(_game.undo))],
    );
    return GameScaffold(
      title: widget.ladder ? l10n.modeLadder : l10n.modeCheckout,
      game: _game,
      takeout: _takeout,
      shownThrows: shown.darts,
      watching: widget.watching,
      onDart: _add,
      onChanged: () => setState(() {}),
      onOutcomeChanged: (_) {
        if (_game.isFinished) _showResult();
      },
      panel: panel,
    );
  }
}

/// Who throws, how hard the finishes are, how many, and the darts for each; for the 121 [ladder], how many attempts
class CheckoutSetupScreen extends StatefulWidget {
  const CheckoutSetupScreen({super.key, this.ladder = false});

  final bool ladder;

  @override
  State<CheckoutSetupScreen> createState() => _CheckoutSetupScreenState();
}

class _CheckoutSetupScreenState extends State<CheckoutSetupScreen> {
  String? _player;
  CheckoutRange _range = CheckoutRange.low;
  int _count = 10;
  int _darts = 9;

  static const _ranges = [CheckoutRange.low, CheckoutRange.middle, CheckoutRange.high];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = _player ?? StatisticsScope.maybeOf(context)?.players.firstOrNull;
    final ladder = widget.ladder;
    return Scaffold(
      appBar: AppBar(title: Text(ladder ? l10n.modeLadder : l10n.modeCheckout)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProfileChoice(selected: player, onSelected: (name) => setState(() => _player = name)),
              if (ladder) ...[
                const SizedBox(height: 16),
                Text(l10n.modeLadderDescription),
              ] else ...[
                const SizedBox(height: 24),
                Text(l10n.checkoutRange, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<CheckoutRange>(
                  segments: [for (final r in _ranges) ButtonSegment(value: r, label: Text('${r.lowest}–${r.highest}'))],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
              ],
              const SizedBox(height: 24),
              Text(ladder ? l10n.ladderAttempts : l10n.checkoutCount, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final n in ladder ? const [10, 20, 30] : const [5, 10, 20])
                    ButtonSegment(value: n, label: Text('$n')),
                ],
                selected: {_count},
                onSelectionChanged: (s) => setState(() => _count = s.first),
              ),
              const SizedBox(height: 24),
              Text(l10n.checkoutDarts, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final n in const [3, 9]) ButtonSegment(value: n, label: Text('$n')),
                ],
                selected: {_darts},
                onSelectionChanged: (s) => setState(() => _darts = s.first),
              ),
              const SizedBox(height: 16),
              Text(l10n.precisionNeedsPoints, style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('start-game'),
                onPressed: player == null
                    ? null
                    : () async {
                        if (!await confirmBoardEmpty(context) || !context.mounted) return;
                        final starts = checkoutStarts(
                          math.Random().nextInt(1 << 31),
                          _count,
                          ladder ? CheckoutRange.ladder : _range,
                        );
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CheckoutScreen(player: player, starts: starts, dartsPerAttempt: _darts, ladder: ladder),
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
