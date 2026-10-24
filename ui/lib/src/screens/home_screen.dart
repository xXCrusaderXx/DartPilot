import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'training_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void comingSoon() => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.comingSoon)));
    final modes = [
      (Icons.flag, l10n.modeX01, l10n.modeX01Description, comingSoon),
      (Icons.grid_on, l10n.modeCricket, l10n.modeCricketDescription, comingSoon),
      (Icons.schedule, l10n.modeAroundTheClock, l10n.modeAroundTheClockDescription, comingSoon),
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
