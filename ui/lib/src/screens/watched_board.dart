import 'package:flutter/material.dart';

import '../board/dart_throw.dart';
import '../board/dartboard.dart';
import '../engine/engine_connection.dart';

/// The board of a game watched on another display: the darts of the visit, no input.
class WatchedBoard extends StatelessWidget {
  const WatchedBoard({super.key, required this.throws});

  final List<DartThrow> throws;

  @override
  Widget build(BuildContext context) {
    final engine = EngineScope.of(context);
    return Center(
      child: Dartboard(
        key: const ValueKey('watched-board'),
        throws: throws,
        geometry: engine.geometry,
        image: engine.boardImage,
      ),
    );
  }
}
