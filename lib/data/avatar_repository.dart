import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Provider for [AvatarRepository].
final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Persists emoji avatars players chose for themselves, keyed by name.
/// Players without an entry use their deterministic default.
class AvatarRepository {
  static const String _boxName = 'player_avatars';
  static const String _keyAvatars = 'avatars';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(_box != null && _box!.isOpen, 'AvatarRepository not initialised');
    return _box!;
  }

  /// Box backing this repository, for full-app backup/restore.
  Box<dynamic> get backupBox => _safeBox;

  Map<String, String> getAll() {
    final raw = _safeBox.get(_keyAvatars) as String?;
    if (raw == null || raw.isEmpty) return {};
    return (json.decode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  Future<void> saveAll(Map<String, String> avatars) async {
    await _safeBox.put(_keyAvatars, json.encode(avatars));
  }
}
