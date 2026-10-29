import 'package:flutter/foundation.dart';

/// How hard a word is to describe without giving it away.
///
/// Every word starts as [unset]; the host rates words after each round.
enum WordDifficulty {
  unset('Unrated'),
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const WordDifficulty(this.label);

  final String label;

  /// The difficulties a player can actually pick after a round.
  static const List<WordDifficulty> ratable = [easy, medium, hard];

  static WordDifficulty fromName(String? name) => WordDifficulty.values
      .firstWhere((d) => d.name == name, orElse: () => WordDifficulty.unset);
}

/// Stable identity of a word concept across languages.
///
/// Words are index-aligned across languages with English as the canonical
/// list, so the English text (plus its theme) identifies the concept no matter
/// which language the round was played in.
@immutable
class WordKey {
  const WordKey({required this.theme, required this.englishWord});

  final String theme;
  final String englishWord;

  // Unit separator: cannot appear in user-typed theme names or words.
  static const _separator = '\u001F';

  /// Case/whitespace-insensitive key used for persistence.
  String get storageKey =>
      '$theme$_separator${englishWord.trim().toLowerCase()}';

  /// Theme component of a [storageKey], for bulk operations per theme.
  static String themeOf(String storageKey) =>
      storageKey.split(_separator).first;

  @override
  bool operator ==(Object other) =>
      other is WordKey && other.storageKey == storageKey;

  @override
  int get hashCode => storageKey.hashCode;

  @override
  String toString() => 'WordKey($theme / $englishWord)';
}

/// Read-only lookup of word ratings. Words without a rating are [unset].
@immutable
class WordDifficultyMap {
  const WordDifficultyMap([this._byKey = const {}]);

  final Map<String, WordDifficulty> _byKey;

  WordDifficulty of(WordKey key) =>
      _byKey[key.storageKey] ?? WordDifficulty.unset;

  /// Number of rated (non-[WordDifficulty.unset]) words.
  int get ratedCount => _byKey.length;
}
