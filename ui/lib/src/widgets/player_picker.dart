import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../stats/statistics.dart';

/// The players of a game, picked from the profiles in throwing order
class PlayerSelection extends ChangeNotifier {
  final List<String> players = [];

  static const int maxPlayers = 8;

  bool get isEmpty => players.isEmpty;

  void toggle(String name) {
    if (!players.remove(name)) {
      if (players.length >= maxPlayers) return;
      players.add(name);
    }
    notifyListeners();
  }
}

/// Asks for the name of a new profile and adds it; the name, or null when cancelled.
Future<String?> createProfile(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _NewProfileDialog());

class _NewProfileDialog extends StatefulWidget {
  const _NewProfileDialog();

  @override
  State<_NewProfileDialog> createState() => _NewProfileDialogState();
}

class _NewProfileDialogState extends State<_NewProfileDialog> {
  final TextEditingController _name = TextEditingController();
  ProfileError? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final statistics = StatisticsScope.maybeOf(context)!;
    final error = await statistics.addProfile(_name.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newProfile),
      content: TextField(
        key: const ValueKey('new-profile-name'),
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: l10n.profileName,
          errorText: switch (_error) {
            ProfileError.empty => l10n.profileNameEmpty,
            ProfileError.exists => l10n.profileNameExists,
            null => null,
          },
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(key: const ValueKey('new-profile-save'), onPressed: _save, child: Text(l10n.createProfile)),
      ],
    );
  }
}

/// Every game is played by profiles: tap them in the order they throw, or create a new one here.
class PlayerPicker extends StatelessWidget {
  const PlayerPicker({super.key, required this.selection});

  final PlayerSelection selection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profiles = StatisticsScope.maybeOf(context)?.players ?? const <String>[];
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final chosen = selection.players;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.players, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              chosen.isEmpty ? l10n.pickPlayersHint : l10n.throwingOrder(chosen.join(' → ')),
              key: const ValueKey('throwing-order'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in profiles)
                  FilterChip(
                    key: ValueKey('pick-$name'),
                    avatar: chosen.contains(name) ? CircleAvatar(child: Text('${chosen.indexOf(name) + 1}')) : null,
                    showCheckmark: false,
                    label: Text(name),
                    selected: chosen.contains(name),
                    onSelected: (_) => selection.toggle(name),
                  ),
                ActionChip(
                  key: const ValueKey('pick-new-profile'),
                  avatar: const Icon(Icons.person_add),
                  label: Text(l10n.newProfile),
                  onPressed: () async {
                    final name = await createProfile(context);
                    if (name != null) selection.toggle(name);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
