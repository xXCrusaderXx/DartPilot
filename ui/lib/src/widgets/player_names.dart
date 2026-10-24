import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Editable list of 1 to 8 player names, shared by the game setups.
class PlayerNamesEditor extends StatefulWidget {
  const PlayerNamesEditor({super.key, required this.controller});

  final PlayerNamesController controller;

  @override
  State<PlayerNamesEditor> createState() => _PlayerNamesEditorState();
}

class PlayerNamesController {
  final List<TextEditingController> fields = [TextEditingController(), TextEditingController()];

  /// Entered names; empty fields become "Player n"
  List<String> names(AppLocalizations l10n) => [
    for (var i = 0; i < fields.length; ++i)
      fields[i].text.trim().isEmpty ? l10n.playerName(i + 1) : fields[i].text.trim(),
  ];

  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
  }
}

class _PlayerNamesEditorState extends State<PlayerNamesEditor> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fields = widget.controller.fields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.players, style: Theme.of(context).textTheme.titleMedium),
        for (var i = 0; i < fields.length; ++i)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              key: ValueKey('player-name-$i'),
              controller: fields[i],
              decoration: InputDecoration(
                hintText: l10n.playerName(i + 1),
                prefixIcon: const Icon(Icons.person),
                suffixIcon: fields.length > 1
                    ? IconButton(
                        tooltip: l10n.removePlayer,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => fields.removeAt(i).dispose()),
                      )
                    : null,
              ),
            ),
          ),
        if (fields.length < 8)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => fields.add(TextEditingController())),
              icon: const Icon(Icons.person_add),
              label: Text(l10n.addPlayer),
            ),
          ),
      ],
    );
  }
}
