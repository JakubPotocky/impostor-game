import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/data/word_difficulty_repository.dart';

/// Exposes word difficulty ratings reactively so screens update on change.
class WordDifficultyNotifier extends Notifier<WordDifficultyMap> {
  late final WordDifficultyRepository _repo;

  @override
  WordDifficultyMap build() {
    _repo = ref.read(wordDifficultyRepositoryProvider);
    return WordDifficultyMap(_repo.getAll());
  }

  Future<void> setDifficulty(WordKey key, WordDifficulty difficulty) async {
    await _repo.setDifficulty(key, difficulty);
    _refresh();
  }

  Future<void> rename(WordKey from, WordKey to) async {
    await _repo.rename(from, to);
    _refresh();
  }

  Future<void> remove(WordKey key) async {
    await _repo.remove(key);
    _refresh();
  }

  Future<void> removeTheme(String theme) async {
    await _repo.removeTheme(theme);
    _refresh();
  }

  void _refresh() => state = WordDifficultyMap(_repo.getAll());
}

/// Provider for [WordDifficultyNotifier].
final wordDifficultyProvider =
    NotifierProvider<WordDifficultyNotifier, WordDifficultyMap>(
        WordDifficultyNotifier.new);
