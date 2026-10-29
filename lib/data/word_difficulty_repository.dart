import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:impostor/core/word_difficulty.dart';

/// Provider for [WordDifficultyRepository].
final wordDifficultyRepositoryProvider =
    Provider<WordDifficultyRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Persists per-word difficulty ratings using Hive.
///
/// Ratings are user data kept apart from theme content, so rating a bundled
/// word doesn't turn its whole theme into a "custom" copy. Only rated words
/// are stored; anything missing is [WordDifficulty.unset].
class WordDifficultyRepository {
  static const String _boxName = 'word_difficulty';
  static const String _keyRatings = 'ratings';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(_box != null && _box!.isOpen,
        'WordDifficultyRepository not initialised');
    return _box!;
  }

  /// Returns all stored ratings keyed by [WordKey.storageKey].
  Map<String, WordDifficulty> getAll() {
    final raw = _safeBox.get(_keyRatings) as String?;
    if (raw == null || raw.isEmpty) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return {
      for (final e in decoded.entries)
        if (WordDifficulty.fromName(e.value as String?) != WordDifficulty.unset)
          e.key: WordDifficulty.fromName(e.value as String?),
    };
  }

  Future<void> setDifficulty(WordKey key, WordDifficulty difficulty) async {
    final all = getAll();
    if (difficulty == WordDifficulty.unset) {
      all.remove(key.storageKey);
    } else {
      all[key.storageKey] = difficulty;
    }
    await _save(all);
  }

  /// Moves a rating when a word is renamed, so edits don't lose it.
  Future<void> rename(WordKey from, WordKey to) async {
    if (from == to) return;
    final all = getAll();
    final rating = all.remove(from.storageKey);
    if (rating == null) return;
    all[to.storageKey] = rating;
    await _save(all);
  }

  Future<void> remove(WordKey key) async {
    final all = getAll();
    if (all.remove(key.storageKey) != null) await _save(all);
  }

  /// Drops every rating in [theme], e.g. when a custom category is deleted.
  Future<void> removeTheme(String theme) async {
    final all = getAll();
    final before = all.length;
    all.removeWhere((key, _) => WordKey.themeOf(key) == theme);
    if (all.length != before) await _save(all);
  }

  Future<void> _save(Map<String, WordDifficulty> all) async {
    await _safeBox.put(
      _keyRatings,
      json.encode(all.map((k, v) => MapEntry(k, v.name))),
    );
  }
}
