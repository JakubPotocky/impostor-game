import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/validators.dart';
import 'package:impostor/data/player_repository.dart';
import 'package:impostor/features/players/players_state.dart';

/// Riverpod Notifier for the player list.
class PlayersNotifier extends Notifier<PlayersState> {
  late final PlayerRepository _repo;

  @override
  PlayersState build() {
    _repo = ref.read(playerRepositoryProvider);
    final stored = _repo.getPlayers();
    return PlayersState(players: stored);
  }

  /// Adds a new player. If [name] is empty, auto-generates "Player X".
  /// Auto-fixes duplicate names.
  void addPlayer(String name) {
    var trimmed = name.trim();

    // Auto-generate name when empty.
    if (trimmed.isEmpty) {
      trimmed = _generateDefaultName();
    }

    if (trimmed.length > AppConstants.maxPlayerNameLength) return;

    final uniqueName = Validators.makeUnique(trimmed, state.players);
    final updated = [...state.players, uniqueName];
    state = state.copyWith(players: updated);
    _repo.savePlayers(updated);
  }

  /// Generates "Player X" where X is the next available number.
  String _generateDefaultName() {
    var number = state.count + 1;
    while (state.players.contains('Player $number')) {
      number++;
    }
    return 'Player $number';
  }

  /// Edits a player's name at the given index.
  void editPlayer(int index, String newName) {
    if (index < 0 || index >= state.count) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > AppConstants.maxPlayerNameLength) return;

    final others = [
      for (var i = 0; i < state.players.length; i++)
        if (i != index) state.players[i],
    ];
    final uniqueName = Validators.makeUnique(trimmed, others);
    final updated = List<String>.from(state.players);
    updated[index] = uniqueName;
    state = state.copyWith(players: updated);
    _repo.savePlayers(updated);
  }

  /// Removes a player at the given index.
  void removePlayer(int index) {
    if (index < 0 || index >= state.count) return;
    final updated = List<String>.from(state.players)..removeAt(index);
    state = state.copyWith(players: updated);
    _repo.savePlayers(updated);
  }

  /// Removes multiple players by their indices.
  void removePlayers(Set<int> indices) {
    final updated = [
      for (var i = 0; i < state.players.length; i++)
        if (!indices.contains(i)) state.players[i],
    ];
    state = state.copyWith(players: updated);
    _repo.savePlayers(updated);
  }

  /// Reorders a player from [oldIndex] to [newIndex].
  void reorderPlayer(int oldIndex, int newIndex) {
    final updated = List<String>.from(state.players);
    var adjustedNew = newIndex;
    if (adjustedNew > oldIndex) adjustedNew--;
    final item = updated.removeAt(oldIndex);
    updated.insert(adjustedNew, item);
    state = state.copyWith(players: updated);
    _repo.savePlayers(updated);
  }
}

/// Provider for [PlayerRepository].
final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Provider for [PlayersNotifier].
final playersProvider =
    NotifierProvider<PlayersNotifier, PlayersState>(PlayersNotifier.new);
