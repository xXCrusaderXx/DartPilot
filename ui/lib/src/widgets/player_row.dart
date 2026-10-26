import 'package:flutter/material.dart';

import '../display.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    final scoreboard = display.styleFor(window) == DisplayStyle.scoreboard;
    final far = display.farFor(window);
    final onBlock = active && scoreboard ? AppColors.background : null;
    final valueStyle =
        (active
                ? (far ? theme.textTheme.displayLarge : theme.textTheme.displayMedium)
                : (far ? theme.textTheme.displaySmall : theme.textTheme.headlineMedium))
            ?.copyWith(fontWeight: FontWeight.w700, color: valueColour ?? onBlock);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          if (active) ...[
            Icon(
              scoreboard ? Icons.play_arrow : Icons.circle,
              size: scoreboard ? 24 : 12,
              color: onBlock ?? theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scoreboard && active ? name.toUpperCase() : name,
                  overflow: TextOverflow.ellipsis,
                  style: (far || active ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)?.copyWith(
                    fontWeight: active ? FontWeight.w800 : null,
                    color: onBlock,
                  ),
                ),
                if (details != null && (!far || detailsFromAfar))
                  Text(
                    details!,
                    key: detailsKey,
                    style: theme.textTheme.bodySmall?.copyWith(color: onBlock ?? theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, key: valueKey, style: valueStyle),
        ],
      ),
    );
    final Widget body;
    if (active && scoreboard) {
      body = Container(color: AppColors.warning, child: row);
    } else if (active) {
      body = Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary, width: 3),
        ),
        child: row,
      );
    } else {
      body = Card(margin: EdgeInsets.zero, child: row);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(opacity: enabled ? 1 : 0.5, child: body),
    );
  }
}
