import 'camera_order.dart';
import 'engine_connection.dart';

/// Where a setup step stands: done, still to do, done but out of date, a problem found by a check, or nothing to
/// finish (an optional step such as the diagnosis)
enum SetupState { done, missing, stale, problem, none }

/// The setup steps' states from what the engine reports, in the order the player takes them
class SetupStatus {
  const SetupStatus({
    required this.assignment,
    required this.calibration,
    required this.check,
    required this.emptyBoard,
  });

  /// Nothing to show without an engine
  static const offline = SetupStatus(
    assignment: SetupState.none,
    calibration: SetupState.none,
    check: SetupState.none,
    emptyBoard: SetupState.none,
  );

  factory SetupStatus.of(EngineConnection engine, CameraOrder order) {
    if (!engine.isConnected) return offline;
    final cameras = engine.hello?.cameras ?? const <String>[];
    final calibration = engine.calibration;
    final refined =
        calibration != null && calibration.cameras.isNotEmpty && calibration.cameras.every((c) => c.refined);
    final moved = calibration?.cameras.any((c) => c.check?.needsCalibration ?? false) ?? false;
    final checked = calibration?.cameras.every((c) => c.check != null) ?? false;
    final board = engine.boardState;
    return SetupStatus(
      assignment: cameras.isEmpty
          ? SetupState.none
          : order.needsAssignment(cameras)
          ? SetupState.missing
          : SetupState.done,
      calibration: calibration == null
          ? SetupState.none
          : !refined
          ? SetupState.missing
          : calibration.refinementStale
          ? SetupState.stale
          : SetupState.done,
      check: !refined
          ? SetupState.none
          : moved
          ? SetupState.problem
          : checked
          ? SetupState.done
          : SetupState.none,
      emptyBoard: board == null
          ? SetupState.none
          : board.referenceStored
          ? SetupState.done
          : SetupState.missing,
    );
  }

  final SetupState assignment;
  final SetupState calibration;
  final SetupState check;
  final SetupState emptyBoard;

  // Equal while nothing shown changes, so a widget that selects it does not rebuild on every engine event
  @override
  bool operator ==(Object other) =>
      other is SetupStatus &&
      other.assignment == assignment &&
      other.calibration == calibration &&
      other.check == check &&
      other.emptyBoard == emptyBoard;

  @override
  int get hashCode => Object.hash(assignment, calibration, check, emptyBoard);

  /// A step the player has to take before detection works well; the settings tab shows a mark for it
  bool get needsAttention => [
    assignment,
    calibration,
    check,
    emptyBoard,
  ].any((s) => s == SetupState.missing || s == SetupState.stale || s == SetupState.problem);
}
