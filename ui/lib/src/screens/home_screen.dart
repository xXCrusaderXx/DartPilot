import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'around_the_clock_screen.dart';
import 'cricket_screen.dart';
import 'training_screen.dart';
import 'x01_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final modes = [
      (
        Icons.flag,
        l10n.modeX01,
        l10n.modeX01Description,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const X01SetupScreen())),
      ),
      (
        Icons.grid_on,
        l10n.modeCricket,
        l10n.modeCricketDescription,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: CricketScreen.setup)),
      ),
      (
        Icons.schedule,
        l10n.modeAroundTheClock,
        l10n.modeAroundTheClockDescription,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: AroundTheClockScreen.setup)),
      ),
      (
        Icons.adjust,
        l10n.modeTraining,
        l10n.modeTrainingDescription,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrainingScreen())),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.chooseGame, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final (icon, title, description, onTap) in modes)
            Card(
              child: ListTile(
                key: ValueKey('mode-$title'),
                leading: Icon(icon, size: 32),
                title: Text(title),
                subtitle: Text(description),
                trailing: const Icon(Icons.chevron_right),
                onTap: onTap,
              ),
            ),
        ],
      ),
    );
  }
}
