import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'checkout_screen.dart';
import 'doubles_screen.dart';
import 'grouping_screen.dart';

/// The trainings that measure every dart against its target in mm (#125)
class PrecisionTrainingScreen extends StatelessWidget {
  const PrecisionTrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trainings = [
      (Icons.blur_circular, l10n.modeGrouping, l10n.modeGroupingDescription, GroupingScreen.setup),
      (Icons.radio_button_unchecked, l10n.modeDoubles, l10n.modeDoublesDescription, DoublesScreen.setup),
      (Icons.sports_score, l10n.modeCheckout, l10n.modeCheckoutDescription, CheckoutScreen.setup),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modePrecision)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (icon, title, description, setup) in trainings)
                Card(
                  child: ListTile(
                    key: ValueKey('mode-$title'),
                    leading: Icon(icon, size: 32),
                    title: Text(title),
                    subtitle: Text(description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: setup)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
