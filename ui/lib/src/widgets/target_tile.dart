import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../display.dart';
import '../theme.dart';

/// What the player at the oche aims at as the panel's headline: the round's target with the round below it, or in
/// other games the player's own target with their name or progress below it
class TargetTile extends StatelessWidget {
  const TargetTile({super.key, required this.target, required this.round, this.label});

  final String target;

  /// The line under the label, such as the round
  final String round;

  /// What the target is, over the line; by default "Target"
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    final far = display.farFor(window);
    // A phone on its side has no height to spare.
    final short = MediaQuery.sizeOf(context).height < 500;
    final targetStyle = scoreStyle(
      far
          ? theme.textTheme.displayLarge
          : short
          ? theme.textTheme.headlineMedium
          : theme.textTheme.displayMedium,
    )?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary, height: 1.0);
    // From afar the target grows with the panel, as the score of the player at the oche does.
    return LayoutBuilder(
      builder: (context, constraints) => _tile(
        context,
        far ? targetStyle?.copyWith(fontSize: (constraints.maxWidth * 0.14).clamp(57, 120).toDouble()) : targetStyle,
        far: far,
        short: short,
      ),
    );
  }

  Widget _tile(BuildContext context, TextStyle? targetStyle, {required bool far, required bool short}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: short ? 8 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
      ),
      child: Row(
        children: [
          // A long line, such as a player's name, is cut short before it takes the target's room.
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (label ?? l10n.roundTarget).toUpperCase(),
                  key: const ValueKey('target-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (far ? theme.textTheme.titleMedium : theme.textTheme.labelLarge)?.copyWith(letterSpacing: 1.2),
                ),
                Text(
                  round,
                  key: const ValueKey('round'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: far ? theme.textTheme.titleLarge : theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(target, key: const ValueKey('round-target'), style: targetStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
