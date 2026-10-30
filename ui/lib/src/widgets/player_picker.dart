import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bots/bot.dart';
import '../stats/statistics.dart';
import '../theme.dart';

/// The players of a game in throwing order: profiles, and bots with their level
class PlayerSelection extends ChangeNotifier {
  final List<String> players = [];

  /// Level of every bot among [players], by its name
  final Map<String, int> bots = {};

  static const int maxPlayers = 8;

  bool get isEmpty => players.isEmpty;

  /// Bot level per player index, as the game screens take it
  Map<int, int> get botIndexes => {
    for (var i = 0; i < players.length; ++i)
      if (bots.containsKey(players[i])) i: bots[players[i]]!,
  };

  void toggle(String name) {
    if (players.remove(name)) {
      bots.remove(name);
    } else {
      if (players.length >= maxPlayers) return;
      players.add(name);
    }
    notifyListeners();
  }

  /// Sets the whole line-up at once, such as the one of the last game
  void setAll(List<String> names, Map<String, int> botLevels) {
    players
      ..clear()
      ..addAll(names.take(maxPlayers));
    bots
      ..clear()
      ..addAll({
        for (final e in botLevels.entries)
          if (players.contains(e.key)) e.key: e.value,
      });
    notifyListeners();
  }

  /// Turns the order round so that [name] throws first and the others follow as before
  void startWith(String name) {
    final i = players.indexOf(name);
    if (i <= 0) return;
    final rotated = [...players.sublist(i), ...players.sublist(0, i)];
    players
      ..clear()
      ..addAll(rotated);
    notifyListeners();
  }

  /// Adds a bot; a second bot of the same level gets a number, so every player's name is unique in the game.
  void addBot(int level, String name) {
    if (players.length >= maxPlayers) return;
    var unique = name;
    for (var n = 2; players.contains(unique); ++n) {
      unique = '$name ($n)';
    }
    players.add(unique);
    bots[unique] = level;
    notifyListeners();
  }
}

String botLevelName(AppLocalizations l10n, int level) => switch (level) {
  1 => l10n.botLevel1,
  2 => l10n.botLevel2,
  3 => l10n.botLevel3,
  4 => l10n.botLevel4,
  5 => l10n.botLevel5,
  6 => l10n.botLevel6,
  7 => l10n.botLevel7,
  8 => l10n.botLevel8,
  9 => l10n.botLevel9,
  _ => l10n.botLevel10,
};

/// Asks which level a bot plays at; the level, or null when cancelled.
Future<int?> pickBotLevel(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.botDifficulty),
      children: [
        for (final level in botLevels)
          SimpleDialogOption(
            key: ValueKey('bot-level-${level.level}'),
            onPressed: () => Navigator.of(context).pop(level.level),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${level.level}')),
              title: Text(botLevelName(l10n, level.level)),
              subtitle: Text(l10n.botAverage(level.average)),
            ),
          ),
      ],
    ),
  );
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
                    avatar: chosen.contains(name)
                        ? CircleAvatar(child: Text('${chosen.indexOf(name) + 1}'))
                        : _dot(context, name),
                    showCheckmark: false,
                    label: Text(name),
                    selected: chosen.contains(name),
                    onSelected: (_) => selection.toggle(name),
                  ),
                for (final name in chosen)
                  if (selection.bots.containsKey(name))
                    InputChip(
                      key: ValueKey('picked-bot-$name'),
                      avatar: CircleAvatar(child: Text('${chosen.indexOf(name) + 1}')),
                      label: Text(name),
                      selected: true,
                      showCheckmark: false,
                      onDeleted: () => selection.toggle(name),
                    ),
                ActionChip(
                  key: const ValueKey('pick-bot'),
                  avatar: const Icon(Icons.smart_toy_outlined),
                  label: Text(l10n.addBot),
                  onPressed: () async {
                    final level = await pickBotLevel(context);
                    if (level != null && context.mounted) {
                      selection.addBot(level, l10n.botName(level, botLevelName(l10n, level)));
                    }
                  },
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

/// One profile for a solo training: tap one, or create a new one here.
class ProfileChoice extends StatelessWidget {
  const ProfileChoice({super.key, required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profiles = StatisticsScope.maybeOf(context)?.players ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.players, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l10n.groupingPickPlayer, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in profiles)
              ChoiceChip(
                key: ValueKey('pick-$name'),
                avatar: _dot(context, name),
                label: Text(name),
                selected: name == selected,
                onSelected: (_) => onSelected(name),
              ),
            ActionChip(
              key: const ValueKey('pick-new-profile'),
              avatar: const Icon(Icons.person_add),
              label: Text(l10n.newProfile),
              onPressed: () async {
                final name = await createProfile(context);
                if (name != null) onSelected(name);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// The profile's colour as a chip's avatar, or none
Widget? _dot(BuildContext context, String name) => switch (StatisticsScope.maybeOf(context)?.colourOf(name)) {
  final colour? => PlayerDot(colour),
  null => null,
};
