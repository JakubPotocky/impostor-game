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
    return pickFromCandidates(
      theme: theme,
      candidates: List.generate(wordCount, (i) => i),
      random: random,
    );
  }

  /// Picks one of [candidates] (indices into [theme]'s word list), avoiding
  /// indices already used this session.
  ///
  /// When every candidate has been used, only those candidates are recycled:
  /// history for words outside the current pool (e.g. filtered out by
  /// difficulty) is kept, so they still won't repeat once back in the pool.
  ///
  /// [weightOf] optionally biases the pick among the still-available words
  /// (weights must be positive); it never changes which words are available.
  int pickFromCandidates({
    required String theme,
    required List<int> candidates,
    required Random random,
    double Function(int index)? weightOf,
  }) {
    assert(candidates.isNotEmpty, 'Candidate list must not be empty');

    final used = _usedIndices.putIfAbsent(theme, () => {});
    var available = candidates.where((i) => !used.contains(i)).toList();

    if (available.isEmpty) {
      used.removeAll(candidates);
      available = List.of(candidates);
    }

    final picked = weightOf == null
        ? available[random.nextInt(available.length)]
        : _weightedPick(available, weightOf, random);
    used.add(picked);
    return picked;
  }

  static int _weightedPick(
    List<int> options,
    double Function(int index) weightOf,
    Random random,
  ) {
    final weights = [for (final i in options) weightOf(i)];
    assert(weights.every((w) => w > 0), 'Weights must be positive');
    final total = weights.fold<double>(0, (sum, w) => sum + w);
    var r = random.nextDouble() * total;
    for (var k = 0; k < options.length; k++) {
      r -= weights[k];
      if (r < 0) return options[k];
    }
    return options.last;
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
