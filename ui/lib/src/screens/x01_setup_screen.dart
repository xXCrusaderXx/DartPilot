import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../games/x01.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import 'x01_screen.dart';

class X01SetupScreen extends StatefulWidget {
  const X01SetupScreen({super.key});

  @override
  State<X01SetupScreen> createState() => _X01SetupScreenState();
}

class _X01SetupScreenState extends State<X01SetupScreen> {
  // The start button follows whether anyone is picked.
  late final PlayerSelection _players = PlayerSelection()..addListener(() => setState(() {}));
  int _startScore = 501;
  bool _doubleIn = false;
  bool _doubleOut = true;
  int _legsToWin = 1;

  @override
  void dispose() {
    _players.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await confirmBoardEmpty(context) || !mounted) return;
    final settings = X01Settings(
      players: List.of(_players.players),
      startScore: _startScore,
      doubleIn: _doubleIn,
      doubleOut: _doubleOut,
      legsToWin: _legsToWin,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => X01Screen(settings: settings, bots: _players.botIndexes),
      ),
    );
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
              PlayerPicker(selection: _players),
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
              FilledButton.icon(
                key: const ValueKey('start-game'),
                onPressed: _players.isEmpty ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
