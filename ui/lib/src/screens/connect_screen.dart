import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/engine_card.dart';

/// Shown while no engine is connected: where the engine runs (this device or the network) and connecting to it.
/// The games also work without an engine, with input by hand.
class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key, required this.onPlayOffline});

  final VoidCallback onPlayOffline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.connectTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(l10n.connectIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              const EngineCard(),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  key: const ValueKey('play-offline'),
                  onPressed: onPlayOffline,
                  icon: const Icon(Icons.keyboard),
                  label: Text(l10n.playWithoutEngine),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
