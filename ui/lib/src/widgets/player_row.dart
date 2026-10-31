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
    this.heroValue = true,
    this.valueLabel,
    this.detailsIcons,
    this.dense = false,
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

  /// Whether the active player's value is the panel's largest figure; false where the game shows what matters more
  /// elsewhere, as Killer does with the double to throw at
  final bool heroValue;

  /// What the value is, small before it, where the bare figure could be read as points: "Target"
  final String? valueLabel;

  /// Icons before the details, as Killer's lives when the row's value is the double to throw at
  final Widget? detailsIcons;

  /// For a panel too low for every player's row at full height: less room around the row, the details on the name's
  /// line and the active value at the size of the others'
  final bool dense;

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
      active && heroValue && !dense
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

    // Progress, hit rate or record: read from the oche as well, where they are part of the game
    final detailsStyle = GameText.of(context).detail?.copyWith(color: onBlock ?? theme.colorScheme.onSurfaceVariant);
    final label = [
      if (valueLabel != null) ...[
        Text(
          valueLabel!.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            color: onBlock ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
      ],
    ];
    Widget row(double width) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 4 : 10),
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
            // Dense, the details follow the name on its line instead of taking one of their own
            child: Flex(
              direction: dense ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: dense ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: dense ? 2 : 0,
                  fit: FlexFit.loose,
                  child: Text(
                    scoreboard && active ? name.toUpperCase() : name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: dense ? 1 : null,
                    // From afar a size above the details below it, as in the X01 panel
                    style:
                        (far
                                ? theme.textTheme.headlineMedium
                                : active
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.titleMedium)
                            ?.copyWith(fontWeight: active ? FontWeight.w800 : null, color: onBlock),
                  ),
                ),
                if (details != null && (!far || detailsFromAfar)) ...[
                  if (dense) const SizedBox(width: 8),
                  Flexible(
                    flex: dense ? 1 : 0,
                    fit: FlexFit.loose,
                    child: Row(
                      mainAxisSize: dense ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        if (detailsIcons != null) ...[
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: IconTheme.merge(
                                data: IconThemeData(
                                  size: (detailsStyle?.fontSize ?? 12) * 1.4,
                                  color: onBlock ?? theme.colorScheme.onSurface,
                                ),
                                child: detailsIcons!,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            details!,
                            key: detailsKey,
                            maxLines: dense ? 1 : null,
                            overflow: dense ? TextOverflow.ellipsis : null,
                            style: detailsStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (active && far && heroValue) ...[
            ...label,
            // From the oche the value at stake grows with the panel, as the X01 score does; long values shrink to fit
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width * 0.6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: valueText(valueStyle?.copyWith(fontSize: _farSize(width), height: 1.0)),
              ),
            ),
          ] else if (valueIcons != null) ...[
            ...label,
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width * 0.5),
              child: FittedBox(fit: BoxFit.scaleDown, child: valueText(valueStyle)),
            ),
          ] else
            // A long value, such as the doubles a Killer throws at, shrinks with its label before it pushes the name
            // out
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width * 0.4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...label,
                    Text(value, key: valueKey, style: valueStyle),
                  ],
                ),
              ),
            ),
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
      padding: EdgeInsets.only(bottom: dense ? 4 : 8),
      child: Opacity(opacity: enabled ? 1 : 0.5, child: body),
    );
  }
}
