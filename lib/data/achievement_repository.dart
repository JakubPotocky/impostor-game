import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:impostor/core/achievements.dart';
import 'package:impostor/data/game_history_repository.dart';

/// Provider for [AchievementRepository].
final achievementRepositoryProvider = Provider<AchievementRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Repository that persists which badges each player has unlocked, using Hive.
class AchievementRepository {
  static const String _boxName = 'achievements';
  static const String _keyUnlocked = 'unlocked';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(
        _box != null && _box!.isOpen, 'AchievementRepository not initialised');
    return _box!;
  }

  /// Returns every unlocked badge, across all players.
  List<UnlockedAchievement> getUnlocked() {
    final raw = _safeBox.get(_keyUnlocked) as String?;
    if (raw == null || raw.isEmpty) return [];
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded
        .map((e) => UnlockedAchievement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the unlocked badges for a single player.
  List<UnlockedAchievement> getUnlockedFor(String playerName) =>
      getUnlocked().where((u) => u.playerName == playerName).toList();

  bool isUnlocked(String badgeId, String playerName) => getUnlocked()
      .any((u) => u.badgeId == badgeId && u.playerName == playerName);

  /// Evaluates the full catalog for [playerName] against [history] and
  /// persists any badges not already unlocked. Returns only the newly
  /// unlocked ones, for celebration UI — call this once per player right
  /// after a game is saved to history.
  List<UnlockedAchievement> evaluateAndUnlock(
    String playerName,
    List<GameRecord> history,
  ) {
    final current = getUnlocked();
    final alreadyIds = current
        .where((u) => u.playerName == playerName)
        .map((u) => u.badgeId)
        .toSet();

    final newly = <UnlockedAchievement>[];
    for (final badge in achievementCatalog) {
      if (alreadyIds.contains(badge.id)) continue;
      if (badge.isUnlockedFor(playerName, history)) {
        newly.add(UnlockedAchievement(
          badgeId: badge.id,
          playerName: playerName,
          unlockedAt: DateTime.now(),
        ));
      }
    }

    if (newly.isNotEmpty) {
      // Fire-and-forget, matching GameHistoryRepository.addGame()'s existing
      // style at this same call site — the in-memory box state (which
      // getUnlocked() reads) updates synchronously regardless.
      _save([...current, ...newly]);
    }
    return newly;
  }

  Future<void> _save(List<UnlockedAchievement> unlocked) async {
    final encoded = json.encode(unlocked.map((u) => u.toJson()).toList());
    await _safeBox.put(_keyUnlocked, encoded);
  }

  /// Clears all unlocked achievements for every player.
  Future<void> clearAll() async {
    await _safeBox.put(_keyUnlocked, '[]');
  }
}

/// A single badge unlock record for one player.
class UnlockedAchievement {
  const UnlockedAchievement({
    required this.badgeId,
    required this.playerName,
    required this.unlockedAt,
  });

  final String badgeId;
  final String playerName;
  final DateTime unlockedAt;

  Map<String, dynamic> toJson() => {
        'badgeId': badgeId,
        'playerName': playerName,
        'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory UnlockedAchievement.fromJson(Map<String, dynamic> json) =>
      UnlockedAchievement(
        badgeId: json['badgeId'] as String,
        playerName: json['playerName'] as String,
        unlockedAt: DateTime.parse(json['unlockedAt'] as String),
      );
}
