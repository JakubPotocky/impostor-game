import 'package:flutter/foundation.dart';

/// Phase of the role-reveal flow for a single player.
enum RevealPhase {
  /// Waiting for the current player to tap "Reveal Role".
  hidden,

  /// Role is being displayed to the current player.
  revealed,
}

/// Immutable state for the role reveal sequence.
@immutable
class RoleRevealState {
  const RoleRevealState({
    this.currentIndex = 0,
    this.totalPlayers = 0,
    this.phase = RevealPhase.hidden,
    this.isComplete = false,
  });

  final int currentIndex;
  final int totalPlayers;
  final RevealPhase phase;
  final bool isComplete;

  RoleRevealState copyWith({
    int? currentIndex,
    int? totalPlayers,
    RevealPhase? phase,
    bool? isComplete,
  }) {
    return RoleRevealState(
      currentIndex: currentIndex ?? this.currentIndex,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      phase: phase ?? this.phase,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
