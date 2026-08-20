import 'package:flutter/foundation.dart';

/// Immutable state model for the player list.
@immutable
class PlayersState {
  const PlayersState({
    this.players = const [],
  });

  final List<String> players;

  int get count => players.length;

  PlayersState copyWith({List<String>? players}) {
    return PlayersState(players: players ?? this.players);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayersState &&
          runtimeType == other.runtimeType &&
          listEquals(players, other.players);

  @override
  int get hashCode => Object.hashAll(players);
}
