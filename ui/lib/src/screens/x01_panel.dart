import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../display.dart';
import '../games/x01.dart';
import '../stats/statistics.dart';
import '../theme.dart';
import '../widgets/precision_text.dart';

/// The X01 score panel in the player's display style: clear (the remaining score large in the app's colours) or a
/// scoreboard (the player at the oche as a bright block, darts and checkout in a strip). From afar it shows only what
/// is read from the oche; where the window is short, as a phone on its side, it packs tighter so the other players
/// stay in view.
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
    this.height,
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

  /// The height the panel has, when known: the score then shrinks so the other players and Undo stay in view
  final double? height;

  /// The remaining score on show: none left after a visit that won the leg, even when the next leg has begun
  int get _shownRemaining => visit.isCheckout ? 0 : game.players[visit.player].remaining;

  /// The big score rolls only within one player's leg; a new player or leg shows at once.
  Key get _rollKey => ValueKey('roll-${visit.player}-${visit.leg}');

  /// Window height, and panel height, below which the panel packs tighter
  static const double shortBelow = 500;
  static const double shortPanelBelow = 360;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final short = height < shortBelow || (this.height ?? double.infinity) < shortPanelBelow;
    return LayoutBuilder(
      builder: (context, constraints) => style == DisplayStyle.scoreboard
          ? _scoreboard(context, constraints.maxWidth, height, short: short)
          : _clear(context, constraints.maxWidth, height, short: short),
    );
  }

  /// The active player's remaining score fills the panel's width, within bounds for near and far; from afar on a tall
  /// screen such as a TV it also grows with the height, and in a short window it leaves room for the others.
  double _bigSize(double width, double height, {required bool short, bool scoreboard = false}) {
    if (short) return (width * 0.24).clamp(48, 80).toDouble();
    final double size =
        (width * 0.34).clamp(56.0, far ? math.max(220.0, height * 0.26) : 120.0) * (scoreboard ? 1.15 : 1);
    final panel = this.height;
    return far || panel == null ? size : math.max(56.0, math.min(size, panel * 0.28));
  }

  /// The leg line on top: from afar large and with the game; in a short window only in a match over several legs,
  /// since a single leg is always leg 1
  Widget? _metaLine(AppLocalizations l10n, ThemeData theme, {required bool short, required bool scoreboard}) {
    if (short && game.settings.legsToWin == 1) return null;
    final text = far ? '${game.settings.startScore} · ${_meta(l10n)}' : _meta(l10n);
    if (scoreboard) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: short ? 4 : 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: (theme.extension<AppPalette>() ?? AppPalette.dark).bad, width: 3)),
        ),
        child: Text(
          text.toUpperCase(),
          style: scoreStyle(far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: short ? 4 : 8),
      child: Text(
        text,
        style: (far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _clear(BuildContext context, double width, double height, {required bool short}) {
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
        ?_metaLine(l10n, theme, short: short, scoreboard: false),
        if (legWon != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LegWon(text: legWon!, big: far),
          ),
        Container(
          key: const ValueKey('active-player'),
          padding: short ? const EdgeInsets.fromLTRB(12, 6, 12, 8) : const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                      style: (far ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_figures(l10n, active) case final figures?) Text(figures, style: theme.textTheme.bodyMedium),
                  if (_legs(active) case final legs?) ...[const SizedBox(width: 12), legs],
                ],
              ),
              _Remaining(
                key: _rollKey,
                name: active.name,
                remaining: _shownRemaining,
                size: _bigSize(width, height, short: short),
              ),
              if (details.contains(PanelDetail.visitDarts))
                _VisitRow(texts: dartTexts, total: visit.points, bust: visit.isBust, big: far, short: short)
              else if (visit.isBust)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.bust, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                ),
              if (checkout != null && details.contains(PanelDetail.checkout))
                _CheckoutLine(route: checkout!, onCall: onCallCheckout, big: far, short: short),
            ],
          ),
        ),
        for (final p in others)
          Padding(
            padding: EdgeInsets.only(top: short ? 6 : 8),
            child: _OtherPlayer(player: p, figures: _otherFigures(l10n, p), legs: _legs(p), big: far, short: short),
          ),
      ],
    );
  }

  Widget _scoreboard(BuildContext context, double width, double height, {required bool short}) {
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
        ?_metaLine(l10n, theme, short: short, scoreboard: true),
        if (legWon != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _LegWon(text: legWon!, big: far),
          ),
        Container(
          key: const ValueKey('active-player'),
          color: block,
          padding: EdgeInsets.fromLTRB(16, short ? 4 : 8, 16, short ? 4 : 8),
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
                      style: scoreStyle(far ? theme.textTheme.headlineMedium : theme.textTheme.headlineSmall)
                          ?.copyWith(color: onBlock, fontWeight: FontWeight.w700, letterSpacing: 0.5),
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
                size: _bigSize(width, height, short: short, scoreboard: true),
                color: onBlock,
              ),
            ],
          ),
        ),
        for (final p in others)
          Container(
            color: theme.colorScheme.surfaceContainerHigh,
            margin: const EdgeInsets.only(top: 2),
            child: _OtherPlayer(
              player: p,
              figures: _otherFigures(l10n, p),
              legs: _legs(p),
              big: far,
              short: short,
              flat: true,
            ),
          ),
        SizedBox(height: short ? 4 : 8),
        Container(
          color: theme.colorScheme.surfaceContainerHigh,
          padding: EdgeInsets.all(short ? 4 : 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (details.contains(PanelDetail.visitDarts))
                _VisitRow(texts: dartTexts, total: visit.points, bust: visit.isBust, big: far, short: short)
              else if (visit.isBust)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.bust, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                ),
              if (checkout != null && details.contains(PanelDetail.checkout))
                _CheckoutLine(route: checkout!, onCall: onCallCheckout, big: far, short: short),
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
        style: scoreStyle(big ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)
            ?.copyWith(color: colour, fontWeight: FontWeight.w700),
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
    this.short = false,
    this.flat = false,
  });

  final X01PlayerState player;
  final String? figures;
  final Widget? legs;
  final bool big;

  /// One line with the figures beside the name, for a short window
  final bool short;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = Text(
      player.name,
      style: big ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium,
      overflow: TextOverflow.ellipsis,
    );
    final figures = this.figures == null
        ? null
        : Text(
            this.figures!,
            overflow: TextOverflow.ellipsis,
            style: (big ? theme.textTheme.titleLarge : theme.textTheme.bodySmall)?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: short ? 2 : 8),
      child: Row(
        children: [
          if (StatisticsScope.maybeOf(context)?.colourOf(player.name) case final colour?) ...[
            PlayerDot(colour),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: short
                ? Row(
                    children: [
                      Flexible(child: name),
                      if (figures != null) ...[const SizedBox(width: 8), Flexible(flex: 2, child: figures)],
                    ],
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [name, ?figures]),
          ),
          if (legs != null) ...[legs!, const SizedBox(width: 16)],
          Text(
            '${player.remaining}',
            key: ValueKey('remaining-${player.name}'),
            style: scoreStyle(
              big
                  ? theme.textTheme.displayMedium
                  : short
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.headlineLarge,
            )?.copyWith(fontWeight: FontWeight.w700, height: short ? 1.1 : null),
          ),
        ],
      ),
    );
    return flat ? row : Card(margin: EdgeInsets.zero, child: row);
  }
}

/// The three darts of the visit and what they come to, or that the visit is bust
class _VisitRow extends StatelessWidget {
  const _VisitRow({
    required this.texts,
    required this.total,
    required this.bust,
    required this.big,
    this.short = false,
  });

  final List<String> texts;
  final int total;
  final bool bust;
  final bool big;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = scoreStyle(
      big
          ? theme.textTheme.headlineMedium
          : short
          ? theme.textTheme.titleLarge
          : theme.textTheme.headlineSmall,
    );
    return Padding(
      padding: EdgeInsets.only(top: short ? 4 : 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; ++i) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: short ? 2 : 8),
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
                  style: style?.copyWith(
                    fontWeight: FontWeight.w600,
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
              padding: EdgeInsets.symmetric(vertical: short ? 2 : 8, horizontal: 4),
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
                  style: style?.copyWith(
                    fontWeight: FontWeight.w700,
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
  const _CheckoutLine({required this.route, required this.onCall, required this.big, this.short = false});

  final List<String> route;
  final VoidCallback onCall;
  final bool big;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final good = StatusColors.of(context).good;
    return Padding(
      padding: EdgeInsets.only(top: short ? 0 : 8),
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
              style: scoreStyle(big ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)
                  ?.copyWith(color: good, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            key: const ValueKey('call-checkout'),
            icon: const Icon(Icons.volume_up),
            tooltip: l10n.callCheckout,
            visualDensity: short ? VisualDensity.compact : null,
            onPressed: onCall,
          ),
        ],
      ),
    );
  }
}
