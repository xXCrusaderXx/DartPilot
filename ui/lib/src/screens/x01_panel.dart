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
    this.legWon,
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

  /// Who won the leg just ended, shown until the next leg's first dart
  final String? legWon;

  /// The remaining score on show: none left after a visit that won the leg, even when the next leg has begun
  int get _shownRemaining => visit.isCheckout ? 0 : game.players[visit.player].remaining;

  /// The big score rolls only within one player's leg; a new player or leg shows at once.
  Key get _rollKey => ValueKey('roll-${visit.player}-${visit.leg}');

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
        if (legWon != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LegWon(text: legWon!, big: far),
          ),
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
                  if (_legs(active) case final legs?) ...[const SizedBox(width: 12), legs],
                ],
              ),
              _Remaining(key: _rollKey, name: active.name, remaining: _shownRemaining, size: _bigSize(width)),
              if (details.contains(PanelDetail.visitDarts))
                _VisitRow(texts: dartTexts, total: visit.points, bust: visit.isBust, big: far)
              else if (visit.isBust)
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
            child: _OtherPlayer(player: p, figures: _otherFigures(l10n, p), legs: _legs(p), big: far),
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
        if (legWon != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _LegWon(text: legWon!, big: far),
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
                  if (_legs(active, colour: onBlock) case final legs?) ...[const SizedBox(width: 12), legs],
                ],
              ),
              _Remaining(
                key: _rollKey,
                name: active.name,
                remaining: _shownRemaining,
                size: _bigSize(width) * 1.15,
                color: onBlock,
              ),
            ],
          ),
        ),
        for (final p in others)
          Container(
            color: theme.colorScheme.surfaceContainerHigh,
            margin: const EdgeInsets.only(top: 2),
            child: _OtherPlayer(player: p, figures: _otherFigures(l10n, p), legs: _legs(p), big: far, flat: true),
          ),
        const SizedBox(height: 8),
        Container(
          color: theme.colorScheme.surfaceContainerHigh,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (details.contains(PanelDetail.visitDarts))
                _VisitRow(texts: dartTexts, total: visit.points, bust: visit.isBust, big: far)
              else if (visit.isBust)
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

  /// The figures the player chose, or null from afar or when there are none; no average before the first dart
  String? _figures(AppLocalizations l10n, X01PlayerState p) {
    if (far) return null;
    final parts = [
      if (details.contains(PanelDetail.average))
        l10n.x01PlayerFigures(p.dartsThrown == 0 ? '–' : decimal(l10n, p.threeDartAverage)),
      if (details.contains(PanelDetail.dartsThrown)) l10n.x01DartsThrown(p.dartsThrown),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// A waiting player's figures and what their last visit in this leg came to, which is also read from afar
  String? _otherFigures(AppLocalizations l10n, X01PlayerState p) {
    final index = game.players.indexOf(p);
    X01Visit? last;
    for (final v in game.visits.reversed) {
      if (v.leg != game.legNumber) break;
      if (v.player == index && v.isComplete) {
        last = v;
        break;
      }
    }
    final parts = [
      ?_figures(l10n, p),
      if (last != null) last.isBust ? l10n.x01LastVisitBust : l10n.x01LastVisit(last.points),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Legs won in a match over more than one leg, near and from afar
  Widget? _legs(X01PlayerState p, {Color? colour}) =>
      game.settings.legsToWin > 1 ? _LegsBadge(name: p.name, legs: p.legsWon, big: far, colour: colour) : null;
}

/// Legs won as a framed badge beside the name
class _LegsBadge extends StatelessWidget {
  const _LegsBadge({required this.name, required this.legs, required this.big, this.colour});

  final String name;
  final int legs;
  final bool big;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colour = this.colour ?? theme.colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 12 : 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: colour, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        l10n.x01Legs(legs),
        key: ValueKey('legs-$name'),
        style: (big ? theme.textTheme.titleLarge : theme.textTheme.titleSmall)?.copyWith(
          color: colour,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// The leg just won, as a line at the top of the panel
class _LegWon extends StatelessWidget {
  const _LegWon({required this.text, required this.big});

  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    return Container(
      key: const ValueKey('leg-won'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.highlight, width: 6)),
        color: theme.colorScheme.surfaceContainerHigh,
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: StatusColors.of(context).good, size: big ? 32 : 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: (big ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The remaining score, counting to its new value when a visit scores
class _Remaining extends StatelessWidget {
  const _Remaining({super.key, required this.name, required this.remaining, required this.size, this.color});

  final String name;
  final int remaining;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge
        ?.copyWith(fontSize: size, fontWeight: FontWeight.w700, height: 1.0, color: color);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: remaining.toDouble()),
      duration: motion(context, const Duration(milliseconds: 250)),
      curve: Curves.easeOut,
      builder: (context, value, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '${value.round()}',
          key: ValueKey('remaining-$name'),
          // The final value for screen readers and tests, not the frames in between
          semanticsLabel: '$remaining',
          style: style,
        ),
      ),
    );
  }
}

class _OtherPlayer extends StatelessWidget {
  const _OtherPlayer({
    required this.player,
    required this.figures,
    required this.legs,
    required this.big,
    this.flat = false,
  });

  final X01PlayerState player;
  final String? figures;
  final Widget? legs;
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
                  Text(
                    figures!,
                    style: (big ? theme.textTheme.titleMedium : theme.textTheme.bodySmall)?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (legs != null) ...[legs!, const SizedBox(width: 16)],
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

/// The three darts of the visit and what they come to, or that the visit is bust
class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.texts, required this.total, required this.bust, required this.big});

  final List<String> texts;
  final int total;
  final bool bust;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          const SizedBox(width: 8),
          Expanded(
            flex: bust ? 2 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: bust
                    ? theme.colorScheme.errorContainer
                    : texts.isEmpty
                    ? theme.colorScheme.surfaceContainerHigh
                    : theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  bust ? l10n.bust : (texts.isEmpty ? '–' : '$total'),
                  key: const ValueKey('visit-total'),
                  maxLines: 1,
                  style: (big ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: bust
                        ? theme.colorScheme.onErrorContainer
                        : texts.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
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
