import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../display.dart';
import '../theme.dart';
import 'winner_dialog.dart';

/// End of a game played alone: [title], what came of it, and the ways on of the winner dialog: the same game again
/// first, then undo, a new game or back to the menu.
Future<void> showGameResult(
  BuildContext context, {
  required String title,
  required Widget content,
  required VoidCallback onUndo,
  required WidgetBuilder newGame,
  required WidgetBuilder again,
}) => showSoloEnd(context, title: title, content: content, onUndo: onUndo, again: again, newGame: newGame);

/// What a game played alone or a training round came to: the [headline] result large, its [details] below, and how
/// it stands against the player's best so far, when there is one: from [value] and [best], or as the [comparison]
/// a training draws itself
class SoloResult extends StatelessWidget {
  const SoloResult({
    super.key,
    required this.headline,
    this.headlineKey = const ValueKey('solo-result'),
    this.details,
    this.value,
    this.best,
    this.bestText,
    this.comparison,
  });

  final String headline;
  final Key headlineKey;
  final String? details;

  /// This game's measure and the best before it, higher being better; [bestText] is the best as shown
  final double? value;
  final double? best;
  final String? bestText;
  final Widget? comparison;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final far = DisplayScope.of(context).farFor(WindowClass.of(context));
    final value = this.value;
    final best = this.best;
    final isBest = value != null && best != null && value > best;
    final comparisonStyle = far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          key: headlineKey,
          style: scoreStyle(far ? theme.textTheme.displayMedium : theme.textTheme.headlineLarge)
              ?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
        ),
        if (details != null) ...[
          const SizedBox(height: 4),
          Text(
            details!,
            style: (far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (comparison != null) ...[
          const SizedBox(height: 12),
          DefaultTextStyle.merge(style: comparisonStyle, child: comparison!),
        ] else if (isBest) ...[
          const SizedBox(height: 12),
          Row(
            key: const ValueKey('new-best'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: AppPalette.of(context).highlight, size: far ? 36 : 24),
              const SizedBox(width: 8),
              Text(l10n.newPersonalBest, style: comparisonStyle?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ] else if (best != null && bestText != null) ...[
          const SizedBox(height: 12),
          Text(l10n.personalBest(bestText!), key: const ValueKey('personal-best'), style: comparisonStyle),
        ],
      ],
    );
  }
}
