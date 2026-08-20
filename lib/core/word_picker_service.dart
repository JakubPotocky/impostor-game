import 'dart:math';

/// Service that picks a random word index from a theme without repetition
/// within the same session (until the pool is exhausted).
///
/// Works on indices so the same word can be displayed in any language.
class WordPickerService {
  WordPickerService();

  /// Tracks indices already used in this session, keyed by theme name.
  final Map<String, Set<int>> _usedIndices = {};

  /// Picks a random index from a word list of [wordCount] items for [theme].
  /// Avoids repeats until the pool is exhausted, then resets.
  int pickWordIndex({
    required String theme,
    required int wordCount,
    required Random random,
  }) {
    assert(wordCount > 0, 'Word list must not be empty');

    final used = _usedIndices[theme] ?? <int>{};
    var available = [
      for (var i = 0; i < wordCount; i++)
        if (!used.contains(i)) i,
    ];

    if (available.isEmpty) {
      _usedIndices[theme] = {};
      available = List.generate(wordCount, (i) => i);
    }

    final picked = available[random.nextInt(available.length)];
    _usedIndices.putIfAbsent(theme, () => {}).add(picked);
    return picked;
  }

  /// Legacy helper — picks a word string directly (used by existing tests).
  String pickWord({
    required String theme,
    required List<String> words,
    required Random random,
  }) {
    final index = pickWordIndex(
      theme: theme,
      wordCount: words.length,
      random: random,
    );
    return words[index];
  }

  /// Resets usage history (e.g., on new session).
  void reset() {
    _usedIndices.clear();
  }
}
