import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/player_avatar.dart';
import 'package:impostor/data/avatar_repository.dart';

/// Chosen emoji avatars (name -> emoji). Names missing here use
/// [PlayerAvatars.defaultEmoji].
class AvatarsNotifier extends Notifier<Map<String, String>> {
  AvatarRepository? _repo;

  @override
  Map<String, String> build() {
    _repo = ref.read(avatarRepositoryProvider);
    return _repo!.getAll();
  }

  String emojiFor(String name) =>
      state[name] ?? PlayerAvatars.defaultEmoji(name);

  /// Sets [name]'s emoji; null goes back to the default.
  void setEmoji(String name, String? emoji) {
    final updated = Map<String, String>.of(state);
    if (emoji == null || emoji == PlayerAvatars.defaultEmoji(name)) {
      updated.remove(name);
    } else {
      updated[name] = emoji;
    }
    _save(updated);
  }

  /// Keeps a chosen avatar attached to a player who was renamed.
  void rename(String from, String to) {
    final emoji = state[from];
    if (emoji == null || from == to) return;
    _save(Map<String, String>.of(state)
      ..remove(from)
      ..[to] = emoji);
  }

  void _save(Map<String, String> updated) {
    state = updated;
    _repo?.saveAll(updated);
  }
}

/// Provider for [AvatarsNotifier].
final avatarsProvider =
    NotifierProvider<AvatarsNotifier, Map<String, String>>(AvatarsNotifier.new);
