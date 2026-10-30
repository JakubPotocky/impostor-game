import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Provider for [RosterRepository].
final rosterRepositoryProvider = Provider<RosterRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// A saved, named list of players (e.g. "Family", "Office crew").
@immutable
class PlayerGroup {
  const PlayerGroup({required this.name, required this.players});

  factory PlayerGroup.fromJson(Map<String, dynamic> json) => PlayerGroup(
        name: json['name'] as String,
        players: (json['players'] as List<dynamic>).cast<String>(),
      );

  final String name;
  final List<String> players;

  Map<String, dynamic> toJson() => {'name': name, 'players': players};
}

/// Persists [PlayerGroup]s using Hive.
class RosterRepository {
  static const String _boxName = 'player_groups';
  static const String _keyGroups = 'groups';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(_box != null && _box!.isOpen, 'RosterRepository not initialised');
    return _box!;
  }

  /// Box backing this repository, for full-app backup/restore.
  Box<dynamic> get backupBox => _safeBox;

  List<PlayerGroup> getGroups() {
    final raw = _safeBox.get(_keyGroups) as String?;
    if (raw == null || raw.isEmpty) return [];
    return (json.decode(raw) as List<dynamic>)
        .map((e) => PlayerGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves [group], replacing one with the same name in place.
  Future<void> saveGroup(PlayerGroup group) async {
    final groups = getGroups();
    final index = groups.indexWhere((g) => g.name == group.name);
    if (index == -1) {
      groups.add(group);
    } else {
      groups[index] = group;
    }
    await _save(groups);
  }

  Future<void> deleteGroup(String name) async {
    await _save(getGroups()..removeWhere((g) => g.name == name));
  }

  Future<void> _save(List<PlayerGroup> groups) async {
    await _safeBox.put(
        _keyGroups, json.encode(groups.map((g) => g.toJson()).toList()));
  }
}
