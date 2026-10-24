import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// End of a match: the winner, one line per player, and undo, new game or back to the menu.
Future<void> showWinnerDialog(
  BuildContext context, {
  required String winner,
  required List<String> lines,
  required VoidCallback onUndo,
  required WidgetBuilder newGame,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.matchWonBy(winner)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in lines) Text(line)],
      ),
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
  );
}
