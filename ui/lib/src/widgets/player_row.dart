import 'package:flutter/material.dart';

import '../display.dart';
import '../stats/statistics.dart';
import '../theme.dart';

/// One player in a score panel, in the player's display style: the player at the oche framed (clear) or as a bright
/// block (scoreboard), the others plain. From afar the details below the name are left out and the value is larger.
class PlayerRow extends StatelessWidget {
  const PlayerRow({
    super.key,
    required this.name,
    required this.value,
    required this.valueKey,
    this.details,
    this.detailsKey,
    this.leading,
    this.active = false,
    this.enabled = true,
    this.valueColour,
    this.detailsFromAfar = false,
    this.valueIcons,
  });

  final String name;

  /// What the game counts for this player: points, the next target, lives
  final String value;
  final Key valueKey;
  final String? details;
  final Key? detailsKey;
  final Widget? leading;
  final bool active;

  /// False for a player who is out
  final bool enabled;
  final Color? valueColour;

  /// The details are part of the game, not figures to look up later: shown from afar too
  final bool detailsFromAfar;

  /// Draws the value as icons, as Killer's lives, sized like the value's text; [value] is then what screen readers say
  final Widget? valueIcons;

  /// The active player's value from afar: like the X01 score, by the panel's width within bounds
  static double _farSize(double width) => (width * 0.18).clamp(57, 140).toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    final scoreboard = display.styleFor(window) == DisplayStyle.scoreboard;
    final far = display.farFor(window);
    final palette = AppPalette.of(context);
    final onBlock = active && scoreboard ? palette.onHighlight : null;
    final colour = StatisticsScope.maybeOf(context)?.colourOf(name);
    final valueStyle = scoreStyle(
      active
          ? (far ? theme.textTheme.displayLarge : theme.textTheme.displayMedium)
          : (far ? theme.textTheme.displaySmall : theme.textTheme.headlineMedium),
    )?.copyWith(fontWeight: FontWeight.w700, color: valueColour ?? onBlock);
    Widget valueText(TextStyle? style) {
      final icons = valueIcons;
      if (icons == null) return Text(value, key: valueKey, style: style);
      return Semantics(
        label: value,
        child: ExcludeSemantics(
          child: IconTheme.merge(
            data: IconThemeData(size: (style?.fontSize ?? 28) * 0.8, color: style?.color),
            child: KeyedSubtree(key: valueKey, child: icons),
          ),
        ),
      );
    }

    Widget row(double width) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          if (active && (scoreboard || colour == null)) ...[
            Icon(
              scoreboard ? Icons.play_arrow : Icons.circle,
              size: scoreboard ? 24 : 12,
              color: onBlock ?? theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          if (colour != null) ...[PlayerDot(colour, ring: onBlock), const SizedBox(width: 8)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scoreboard && active ? name.toUpperCase() : name,
                  overflow: TextOverflow.ellipsis,
                  // From afar a size above the details below it, as in the X01 panel
                  style:
                      (far
                              ? theme.textTheme.headlineMedium
                              : active
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.titleMedium)
                          ?.copyWith(fontWeight: active ? FontWeight.w800 : null, color: onBlock),
                ),
                if (details != null && (!far || detailsFromAfar))
                  Text(
                    details!,
                    key: detailsKey,
                    // Progress, hit rate or record: read from the oche as well, where they are part of the game
                    style: GameText.of(context).detail?.copyWith(color: onBlock ?? theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (active && far)
            // From the oche the value at stake grows with the panel, as the X01 score does; long values shrink to fit
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width * 0.6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: valueText(valueStyle?.copyWith(fontSize: _farSize(width), height: 1.0)),
              ),
            )
          else if (valueIcons != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width * 0.5),
              child: FittedBox(fit: BoxFit.scaleDown, child: valueText(valueStyle)),
            )
          else
            Text(value, key: valueKey, style: valueStyle),
        ],
      ),
    );
    final Widget content = LayoutBuilder(builder: (context, constraints) => row(constraints.maxWidth));
    final Widget body;
    if (active && scoreboard) {
      body = Container(color: palette.highlight, child: content);
    } else if (active) {
      body = Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary, width: 3),
        ),
        child: content,
      );
    } else {
      body = Card(margin: EdgeInsets.zero, child: content);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(opacity: enabled ? 1 : 0.5, child: body),
    );
  }
}
