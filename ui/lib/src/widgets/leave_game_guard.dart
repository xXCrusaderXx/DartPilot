import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Asks before back leaves a game that has darts and is not over; the game is then kept as unfinished.
class LeaveGameGuard extends StatelessWidget {
  const LeaveGameGuard({super.key, required this.canLeave, required this.child});

  /// Nothing would be lost: no dart yet, the game is over, or it is only watched
  final bool canLeave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final l10n = AppLocalizations.of(context);
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.leaveGameTitle),
            content: Text(l10n.leaveGameText),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
              FilledButton(
                key: const ValueKey('leave-game'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.leaveGame),
              ),
            ],
          ),
        );
        if (leave == true) navigator.pop();
      },
      child: child,
    );
  }
}
