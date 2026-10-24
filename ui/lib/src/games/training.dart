import '../board/dart_throw.dart';
import 'dart_game.dart';

/// Free throwing: every dart is counted, three darts make a visit. Pure logic, no UI.
class Training implements DartGame {
  final List<DartThrow> _throws = [];

  @override
  List<DartThrow> get throws => List.unmodifiable(_throws);

  @override
  int get dartsInVisit => _throws.length % 3;

  @override
  bool get isFinished => false;

  @override
  void replace(int index, DartThrow dart) => _throws[index] = dart;

  int get dartCount => _throws.length;

  int get totalPoints => _throws.fold(0, (sum, t) => sum + t.score.points);

  /// Average points per three darts, 0 before the first dart
  double get threeDartAverage => _throws.isEmpty ? 0 : 3 * totalPoints / _throws.length;

  /// Darts of the visit in progress; a full visit stays visible until the next dart starts a new one.
  List<DartThrow> get currentVisit {
    if (_throws.isEmpty) return const [];
    final start = (_throws.length - 1) ~/ 3 * 3;
    return List.unmodifiable(_throws.sublist(start));
  }

  int get visitNumber => _throws.isEmpty ? 1 : (_throws.length - 1) ~/ 3 + 1;

  @override
  void add(DartThrow dart) => _throws.add(dart);

  @override
  void undo() {
    if (_throws.isNotEmpty) _throws.removeLast();
  }
}
