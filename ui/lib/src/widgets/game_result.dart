import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'leave_game_guard.dart';

/// End of a game without one winner, a draw or a game played alone: [title], what came of it, and the buttons of the
/// winner dialog: undo, new game or back to the menu.
Future<void> showGameResult(
  BuildContext context, {
  required String title,
  required Widget content,
  required VoidCallback onUndo,
  required WidgetBuilder newGame,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => EndOfGameBack(
      gameContext: context,
      child: AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onUndo();
            },
            child: Text(l10n.undo),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: newGame));
            },
            child: Text(l10n.newGame),
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
    ),
  );
}

/// What a game played alone came to: the [headline] result large, its [details] small, and how it stands against the
/// player's best so far, when there is one
class SoloResult extends StatelessWidget {
  const SoloResult({super.key, required this.headline, this.details, this.value, this.best, this.bestText});

  final String headline;
  final String? details;

  /// This game's measure and the best before it, higher being better; [bestText] is the best as shown
  final double? value;
  final double? best;
  final String? bestText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final value = this.value;
    final best = this.best;
    final isBest = value != null && best != null && value > best;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          key: const ValueKey('solo-result'),
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (details != null) ...[
          const SizedBox(height: 4),
          Text(details!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        if (isBest) ...[
          const SizedBox(height: 12),
          Row(
            key: const ValueKey('new-best'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: AppPalette.of(context).highlight),
              const SizedBox(width: 8),
              Text(l10n.newPersonalBest, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ] else if (best != null && bestText != null) ...[
          const SizedBox(height: 12),
          Text(l10n.personalBest(bestText!), key: const ValueKey('personal-best'), style: theme.textTheme.titleSmall),
        ],
      ],
    );
  }
}
