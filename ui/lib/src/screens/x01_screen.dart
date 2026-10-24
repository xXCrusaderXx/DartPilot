import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/x01.dart';
import '../input/game_input.dart';
import '../widgets/winner_dialog.dart';
import 'x01_setup_screen.dart';

class X01Screen extends StatefulWidget {
  const X01Screen({super.key, required this.settings});

  final X01Settings settings;

  @override
  State<X01Screen> createState() => _X01ScreenState();
}

class _X01ScreenState extends State<X01Screen> {
  late final X01Game _game = X01Game(widget.settings);

  void _add(DartThrow dart) {
    final legBefore = _game.legNumber;
    final playerBefore = _game.current;
    setState(() => _game.add(dart));
    final l10n = AppLocalizations.of(context);
    if (_game.isFinished) {
      _showWinner();
    } else if (_game.legNumber != legBefore) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.legWonBy(_game.players[playerBefore].name))));
    }
  }

  Future<void> _showWinner() {
    final l10n = AppLocalizations.of(context);
    return showWinnerDialog(
      context,
      winner: _game.players[_game.winner!].name,
      lines: [
        for (final p in _game.players)
          '${p.name}: ${l10n.legs} ${p.legsWon}, ${l10n.average} ${p.threeDartAverage.toStringAsFixed(1)}',
      ],
      onUndo: () => setState(_game.undo),
      newGame: (_) => const X01SetupScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visit = _game.currentVisit;
    final checkout = _game.checkoutSuggestion;

    final scoreboard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.leg(_game.legNumber), style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < _game.players.length; ++i) _PlayerCard(_game.players[i], active: i == _game.current),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 3; ++i)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      i < visit.darts.length ? _dartText(l10n, visit.darts[i]) : '–',
                      key: ValueKey('visit-dart-$i'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (visit.isBust) Text(l10n.bust, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
        if (checkout != null)
          Card(
            color: theme.colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.flag),
              title: Text(l10n.checkout),
              subtitle: Text(checkout.join('  '), key: const ValueKey('checkout'), style: theme.textTheme.titleLarge),
            ),
          ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _game.canUndo ? () => setState(_game.undo) : null,
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    final input = GameInput(
      game: _game,
      shownThrows: [for (final d in visit.darts) d.dart],
      onDart: _add,
      onChanged: () => setState(() {}),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${widget.settings.startScore}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth > constraints.maxHeight
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: input),
                    const SizedBox(width: 24),
                    SizedBox(width: 340, child: scoreboard),
                  ],
                )
              : Column(
                  children: [
                    Expanded(flex: 3, child: input),
                    const SizedBox(height: 16),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(child: SizedBox(height: 420, child: scoreboard)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _dartText(AppLocalizations l10n, X01Dart dart) => switch (dart.result) {
    DartResult.notIn => '${dart.dart.score.label} (${l10n.notIn})',
    _ => dart.dart.score.label,
  };
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard(this.player, {required this.active});

  final X01PlayerState player;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      color: active ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (active) const Icon(Icons.arrow_right),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name, style: theme.textTheme.titleMedium),
                  Text(
                    '${l10n.legs} ${player.legsWon} · Ø ${player.threeDartAverage.toStringAsFixed(1)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text('${player.remaining}', key: ValueKey('remaining-${player.name}'), style: theme.textTheme.displaySmall),
          ],
        ),
      ),
    );
  }
}
