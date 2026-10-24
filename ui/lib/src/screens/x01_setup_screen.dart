import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../games/x01.dart';
import 'x01_screen.dart';

class X01SetupScreen extends StatefulWidget {
  const X01SetupScreen({super.key});

  @override
  State<X01SetupScreen> createState() => _X01SetupScreenState();
}

class _X01SetupScreenState extends State<X01SetupScreen> {
  final List<TextEditingController> _names = [TextEditingController(), TextEditingController()];
  int _startScore = 501;
  bool _doubleIn = false;
  bool _doubleOut = true;
  int _legsToWin = 1;

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    final l10n = AppLocalizations.of(context);
    final settings = X01Settings(
      players: [
        for (var i = 0; i < _names.length; ++i)
          _names[i].text.trim().isEmpty ? l10n.playerName(i + 1) : _names[i].text.trim(),
      ],
      startScore: _startScore,
      doubleIn: _doubleIn,
      doubleOut: _doubleOut,
      legsToWin: _legsToWin,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => X01Screen(settings: settings)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.x01Setup)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.players, style: theme.textTheme.titleMedium),
              for (var i = 0; i < _names.length; ++i)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    key: ValueKey('player-name-$i'),
                    controller: _names[i],
                    decoration: InputDecoration(
                      hintText: l10n.playerName(i + 1),
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: _names.length > 1
                          ? IconButton(
                              tooltip: l10n.removePlayer,
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _names.removeAt(i).dispose()),
                            )
                          : null,
                    ),
                  ),
                ),
              if (_names.length < 8)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _names.add(TextEditingController())),
                    icon: const Icon(Icons.person_add),
                    label: Text(l10n.addPlayer),
                  ),
                ),
              const SizedBox(height: 16),
              Text(l10n.startScore, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final s in [301, 501, 701]) ButtonSegment(value: s, label: Text('$s')),
                ],
                selected: {_startScore},
                onSelectionChanged: (s) => setState(() => _startScore = s.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(l10n.doubleIn),
                value: _doubleIn,
                onChanged: (v) => setState(() => _doubleIn = v),
              ),
              SwitchListTile(
                title: Text(l10n.doubleOut),
                value: _doubleOut,
                onChanged: (v) => setState(() => _doubleOut = v),
              ),
              ListTile(
                title: Text(l10n.legsToWin),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _legsToWin > 1 ? () => setState(() => _legsToWin--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_legsToWin', style: theme.textTheme.titleLarge),
                    IconButton(onPressed: () => setState(() => _legsToWin++), icon: const Icon(Icons.add)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: Text(l10n.startGame)),
            ],
          ),
        ),
      ),
    );
  }
}
