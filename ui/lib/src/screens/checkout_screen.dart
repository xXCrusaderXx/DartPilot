import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/checkout_trainer.dart';
import '../games/dart_game.dart';
import '../games/x01.dart';
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
    if (_game.isFinished) _showResult();
  }

  Future<void> _showResult() {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.groupingDone),
        content: Text(
          [
            '${l10n.statsCheckoutRate}: ${_game.checkouts} / ${_game.attemptsDone}',
            if (widget.ladder) l10n.ladderBest(_game.bestCheckout?.toString() ?? '–'),
          ].join('\n'),
          key: const ValueKey('checkout-result'),
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
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => CheckoutScreen(
                    player: widget.player,
                    starts: checkoutStarts(
                      math.Random().nextInt(1 << 31),
                      widget.starts.length,
                      widget.ladder ? CheckoutRange.ladder : _rangeOf(widget.starts),
                    ),
                    dartsPerAttempt: widget.dartsPerAttempt,
                    ladder: widget.ladder,
                  ),
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

  static CheckoutRange _rangeOf(List<int> starts) =>
      CheckoutRange.values.firstWhere((r) => starts.first <= r.highest, orElse: () => CheckoutRange.high);

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

    final panel = ListView(
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.player, style: theme.textTheme.titleMedium)),
            Text(
              '${_game.isFinished ? 0 : attempt.remaining}',
              key: const ValueKey('checkout-remaining'),
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
        Text(
          '${l10n.checkoutProgress(_game.attempts.length, widget.starts.length)}  ·  '
          '${l10n.statsCheckoutRate} ${_game.checkouts} / ${_game.attemptsDone}',
          key: const ValueKey('checkout-progress'),
        ),
        if (route != null) ...[
          const SizedBox(height: 8),
          Text(l10n.checkoutAim(route.first), key: const ValueKey('checkout-aim'), style: theme.textTheme.titleLarge),
          if (route.length > 1) Text(route.join('  ')),
        ],
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
            '${shown.start}: ${shown.checkedOut ? l10n.checkoutHit : l10n.checkoutMissed}',
            key: const ValueKey('checkout-last-result'),
            style: theme.textTheme.titleMedium,
          ),
        for (var i = shown.darts.length - 1; i >= 0; --i)
          MissTile(
            key: ValueKey('checkout-dart-${firstDart + i}'),
            number: i + 1,
            dart: shown.darts[i],
            target: PrecisionTarget.parse(shown.aims[i]),
            showTarget: true,
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _game.throws.isEmpty || widget.watching ? null : () => setState(_game.undo),
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    return LeaveGameGuard(
      canLeave: widget.watching || _game.isFinished || currentRecord.throws.isEmpty,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.modeCheckout)),
        body: GameLayout(
          input: widget.watching
              ? WatchedBoard(throws: shown.darts)
              : GameInput(
                  game: _game,
                  takeout: _takeout,
                  shownThrows: shown.darts,
                  onDart: _add,
                  onChanged: () => setState(() {}),
                ),
          panel: panel,
        ),
      ),
    );
  }
}

/// Who throws, how hard the finishes are, how many, and the darts for each
class CheckoutSetupScreen extends StatefulWidget {
  const CheckoutSetupScreen({super.key});

  @override
  State<CheckoutSetupScreen> createState() => _CheckoutSetupScreenState();
}

class _CheckoutSetupScreenState extends State<CheckoutSetupScreen> {
  String? _player;
  CheckoutRange _range = CheckoutRange.low;
  int _count = 10;
  int _darts = 9;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = _player ?? StatisticsScope.maybeOf(context)?.players.firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeCheckout)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProfileChoice(selected: player, onSelected: (name) => setState(() => _player = name)),
              const SizedBox(height: 24),
              Text(l10n.checkoutRange, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<CheckoutRange>(
                segments: [
                  for (final r in CheckoutRange.values)
                    ButtonSegment(
                      value: r,
                      label: Text(r == CheckoutRange.ladder ? '121 ↑' : '${r.lowest}–${r.highest}'),
                    ),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(height: 24),
              Text(l10n.checkoutCount, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final n in const [5, 10, 20]) ButtonSegment(value: n, label: Text('$n')),
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
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('start-game'),
                onPressed: player == null
                    ? null
                    : () async {
                        if (!await confirmBoardEmpty(context) || !context.mounted) return;
                        final starts = checkoutStarts(math.Random().nextInt(1 << 31), _count, _range);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => CheckoutScreen(
                              player: player,
                              starts: starts,
                              dartsPerAttempt: _darts,
                              ladder: _range == CheckoutRange.ladder,
                            ),
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
