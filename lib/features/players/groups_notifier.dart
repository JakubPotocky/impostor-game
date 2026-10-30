import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/roster_repository.dart';
import 'package:impostor/features/players/players_notifier.dart';

/// Saved player groups, plus save/load/delete actions.
class GroupsNotifier extends Notifier<List<PlayerGroup>> {
  late final RosterRepository _repo;

  @override
  List<PlayerGroup> build() {
    _repo = ref.read(rosterRepositoryProvider);
    return _repo.getGroups();
  }

  /// Saves the current player list as [name], replacing a same-named group.
  Future<void> saveCurrent(String name) async {
    await _repo.saveGroup(PlayerGroup(
      name: name,
      players: List.of(ref.read(playersProvider).players),
    ));
    state = _repo.getGroups();
  }

  /// Replaces the current players with [group]'s.
  void load(PlayerGroup group) {
    ref.read(playersProvider.notifier).setPlayers(group.players);
  }

  Future<void> delete(String name) async {
    await _repo.deleteGroup(name);
    state = _repo.getGroups();
  }
}

/// Provider for [GroupsNotifier].
final groupsProvider =
    NotifierProvider<GroupsNotifier, List<PlayerGroup>>(GroupsNotifier.new);
