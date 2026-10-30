import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../display.dart';
import '../games/x01.dart';
import '../stats/statistics.dart';
import '../theme.dart';
import '../widgets/precision_text.dart';

/// The X01 score panel in the player's display style: clear (the remaining score large in the app's colours) or a
/// scoreboard (the player at the oche as a bright block, darts and checkout in a strip). From afar it shows only what
/// is read from the oche.
class X01Panel extends StatelessWidget {
  const X01Panel({
    super.key,
    required this.game,
    required this.visit,
    required this.dartTexts,
    required this.checkout,
    required this.onCallCheckout,
    required this.style,
    required this.far,
    this.details = DisplaySettings.defaultPanelDetails,
  });

  final X01Game game;

  /// The visit on show: the one in progress, or the one that ended while its darts are in the board
  final X01Visit visit;
  final List<String> dartTexts;
  final List<String>? checkout;
  final VoidCallback onCallCheckout;
  final DisplayStyle style;
  final bool far;

  /// What the panel shows besides the score
  final Set<PanelDetail> details;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => style == DisplayStyle.scoreboard
          ? _scoreboard(context, constraints.maxWidth)
          : _clear(context, constraints.maxWidth),
    );
  }

  /// The active player's remaining score fills the panel's width, within bounds for near and far
  double _bigSize(double width) => (width * 0.34).clamp(56, far ? 220 : 120).toDouble();

  Widget _clear(BuildContext context, double width) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final active = game.players[visit.player];
    final others = [
      for (var i = 0; i < game.players.length; ++i)
        if (i != visit.player) game.players[i],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_meta(l10n), style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('active-player'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primary, width: 3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (StatisticsScope.maybeOf(context)?.colourOf(active.name) case final colour?)
                    PlayerDot(colour)
                  else
                    Icon(Icons.circle, size: 12, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      active.name,
                      style: (far ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge)?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_figures(l10n, active) case final figures?) Text(figures, style: theme.textTheme.bodyMedium),
                ],
              ),
              _Remaining(player: active, size: _bigSize(width)),
              if (details.contains(PanelDetail.visitDarts)) _VisitRow(texts: dartTexts, big: far),
              if (visit.isBust)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.bust, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                ),
              if (checkout != null && details.contains(PanelDetail.checkout))
                _CheckoutLine(route: checkout!, onCall: onCallCheckout, big: far),
            ],
          ),
        ),
        for (final p in others)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _OtherPlayer(player: p, figures: _figures(l10n, p), big: far),
          ),
      ],
    );
  }

  Widget _scoreboard(BuildContext context, double width) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final block = palette.highlight;
    final onBlock = palette.onHighlight;
    final active = game.players[visit.player];
    final others = [
      for (var i = 0; i < game.players.length; ++i)
        if (i != visit.player) game.players[i],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.bad, width: 3)),
          ),
          child: Text(
            _meta(l10n).toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
        ),
        Container(
          key: const ValueKey('active-player'),
          color: block,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.play_arrow, color: onBlock),
                  const SizedBox(width: 4),
                  if (StatisticsScope.maybeOf(context)?.colourOf(active.name) case final colour?) ...[
                    PlayerDot(colour, ring: onBlock),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      active.name.toUpperCase(),
                      style: (far ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge)?.copyWith(
                        color: onBlock,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_figures(l10n, active) case final figures?)
                    Text(
                      figures,
                      style: theme.textTheme.bodyMedium?.copyWith(color: onBlock, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              _Remaining(player: active, size: _bigSize(width) * 1.15, color: onBlock),
            ],
          ),
        ),
        for (final p in others)
          Container(
            color: theme.colorScheme.surfaceContainerHigh,
            margin: const EdgeInsets.only(top: 2),
            child: _OtherPlayer(player: p, figures: _figures(l10n, p), big: far, flat: true),
          ),
        const SizedBox(height: 8),
        Container(
          color: theme.colorScheme.surfaceContainerHigh,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (details.contains(PanelDetail.visitDarts)) _VisitRow(texts: dartTexts, big: far),
              if (visit.isBust)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.bust, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                ),
              if (checkout != null && details.contains(PanelDetail.checkout))
                _CheckoutLine(route: checkout!, onCall: onCallCheckout, big: far),
            ],
          ),
        ),
      ],
    );
  }

  String _meta(AppLocalizations l10n) =>
      game.settings.legsToWin > 1 ? l10n.x01LegOf(game.legNumber, game.settings.legsToWin) : l10n.leg(game.legNumber);

  /// Legs won and the figures the player chose, or null from afar or when there are none
  String? _figures(AppLocalizations l10n, X01PlayerState p) {
    if (far) return null;
    final parts = [
      if (game.settings.legsToWin > 1) l10n.x01Legs(p.legsWon),
      if (details.contains(PanelDetail.average)) l10n.x01PlayerFigures(decimal(l10n, p.threeDartAverage)),
      if (details.contains(PanelDetail.dartsThrown)) l10n.x01DartsThrown(p.dartsThrown),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// The remaining score, counting to its new value when a visit scores
class _Remaining extends StatelessWidget {
  const _Remaining({required this.player, required this.size, this.color});

  final X01PlayerState player;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge
        ?.copyWith(fontSize: size, fontWeight: FontWeight.w700, height: 1.0, color: color);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: player.remaining.toDouble()),
      duration: motion(context, const Duration(milliseconds: 250)),
      curve: Curves.easeOut,
      builder: (context, value, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '${value.round()}',
          key: ValueKey('remaining-${player.name}'),
          // The final value for screen readers and tests, not the frames in between
          semanticsLabel: '${player.remaining}',
          style: style,
        ),
      ),
    );
  }
}

class _OtherPlayer extends StatelessWidget {
  const _OtherPlayer({required this.player, required this.figures, required this.big, this.flat = false});

  final X01PlayerState player;
  final String? figures;
  final bool big;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (StatisticsScope.maybeOf(context)?.colourOf(player.name) case final colour?) ...[
            PlayerDot(colour),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: big ? theme.textTheme.titleLarge : theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (figures != null)
                  Text(figures!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '${player.remaining}',
            key: ValueKey('remaining-${player.name}'),
            style: (big ? theme.textTheme.displayMedium : theme.textTheme.headlineMedium)?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return flat ? row : Card(margin: EdgeInsets.zero, child: row);
  }
}

/// The three darts of the visit
class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.texts, required this.big});

  final List<String> texts;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; ++i) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  i < texts.length ? texts[i] : '–',
                  key: ValueKey('visit-dart-$i'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (big ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
                    color: i < texts.length ? null : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine({required this.route, required this.onCall, required this.big});

  final List<String> route;
  final VoidCallback onCall;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final good = StatusColors.of(context).good;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.flag, color: good, size: big ? 32 : 20),
          const SizedBox(width: 8),
          Text(
            l10n.checkout,
            style: (big ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              route.join('  '),
              key: const ValueKey('checkout'),
              style: (big ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
                color: good,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('call-checkout'),
            icon: const Icon(Icons.volume_up),
            tooltip: l10n.callCheckout,
            onPressed: onCall,
          ),
        ],
      ),
    );
  }
}
