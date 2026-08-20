import 'package:hive/hive.dart';

/// Repository that persists the player list between sessions using Hive.
class PlayerRepository {
  static const String _boxName = 'players';

  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Box<String> get _safeBox {
    assert(_box != null && _box!.isOpen, 'PlayerRepository not initialised');
    return _box!;
  }

  /// Returns all stored player names in order.
  List<String> getPlayers() {
    return _safeBox.values.toList();
  }

  /// Replaces the entire player list.
  Future<void> savePlayers(List<String> players) async {
    await _safeBox.clear();
    await _safeBox.addAll(players);
  }

  /// Clears all players.
  Future<void> clear() async {
    await _safeBox.clear();
  }
}
