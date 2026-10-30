import 'package:flutter/material.dart';

import '../screens/game_layout.dart';

/// A score panel for games of up to eight players: [header] on top, the [players] in a list that keeps the one at the
/// oche ([active]) in view, and [footer], the visit's darts and Undo, always at the foot. A panel too short for that
/// scrolls as one.
class PlayersPanel extends StatefulWidget {
  const PlayersPanel({super.key, this.header = const [], required this.players, this.active, this.footer = const []});

  final List<Widget> header;
  final List<Widget> players;
  final int? active;
  final List<Widget> footer;

  /// Below this height the list would have no room left between header and footer
  static const double pinnedFrom = 300;

  @override
  State<PlayersPanel> createState() => _PlayersPanelState();
}

class _PlayersPanelState extends State<PlayersPanel> {
  final List<GlobalKey> _keys = [];
  int? _shown;

  void _showActive() {
    final active = widget.active;
    if (active == null || active == _shown || active >= _keys.length) return;
    final target = _keys[active].currentContext;
    if (target == null) return;
    _shown = active;
    final still = MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: still ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    while (_keys.length < widget.players.length) {
      _keys.add(GlobalKey());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showActive();
    });
    final players = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var i = 0; i < widget.players.length; ++i) KeyedSubtree(key: _keys[i], child: widget.players[i])],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < PlayersPanel.pinnedFrom) {
          return ScrollingPanel(top: [...widget.header, players], bottom: widget.footer);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...widget.header,
            Expanded(child: SingleChildScrollView(child: players)),
            if (widget.footer.isNotEmpty) const SizedBox(height: 12),
            ...widget.footer,
          ],
        );
      },
    );
  }
}
