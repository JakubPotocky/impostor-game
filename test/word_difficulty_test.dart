import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/data/word_difficulty_repository.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';

void main() {
  group('WordKey', () {
    test('is case- and whitespace-insensitive on the word', () {
      expect(const WordKey(theme: 'Animals', englishWord: 'Lion'),
          const WordKey(theme: 'Animals', englishWord: ' lion '));
    });

    test('differs across themes', () {
      expect(const WordKey(theme: 'Animals', englishWord: 'Seal'),
          isNot(const WordKey(theme: 'Objects', englishWord: 'Seal')));
    });

    test('exposes its theme from a storage key', () {
      const key = WordKey(theme: 'Internet Culture', englishWord: 'Meme');
      expect(WordKey.themeOf(key.storageKey), 'Internet Culture');
    });
  });

  test('unrated words default to unset', () {
    const map = WordDifficultyMap();
    expect(map.of(const WordKey(theme: 'Animals', englishWord: 'Lion')),
        WordDifficulty.unset);
  });

  test('setup state allows every difficulty by default', () {
    const state = GameSetupState();
    expect(state.allowedDifficulties, WordDifficulty.values.toSet());
    expect(state.isDifficultyFiltered, isFalse);
    expect(
      state.copyWith(allowedDifficulties: {WordDifficulty.easy})
          .isDifficultyFiltered,
      isTrue,
    );
  });

  group('WordDifficultyRepository', () {
    late Directory dir;
    late WordDifficultyRepository repo;
    const lion = WordKey(theme: 'Animals', englishWord: 'Lion');
    const tiger = WordKey(theme: 'Animals', englishWord: 'Tiger');
    const pizza = WordKey(theme: 'Food', englishWord: 'Pizza');

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('word_difficulty_test');
      Hive.init(dir.path);
      repo = WordDifficultyRepository();
      await repo.init();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    WordDifficulty of(WordKey key) => WordDifficultyMap(repo.getAll()).of(key);

    test('stores and clears ratings', () async {
      await repo.setDifficulty(lion, WordDifficulty.hard);
      expect(of(lion), WordDifficulty.hard);

      await repo.setDifficulty(lion, WordDifficulty.unset);
      expect(repo.getAll(), isEmpty);
    });

    test('rename carries the rating to the new word', () async {
      await repo.setDifficulty(lion, WordDifficulty.easy);
      await repo.rename(lion, tiger);
      expect(of(lion), WordDifficulty.unset);
      expect(of(tiger), WordDifficulty.easy);
    });

    test('removeTheme only drops ratings in that theme', () async {
      await repo.setDifficulty(lion, WordDifficulty.easy);
      await repo.setDifficulty(pizza, WordDifficulty.medium);
      await repo.removeTheme('Animals');
      expect(of(lion), WordDifficulty.unset);
      expect(of(pizza), WordDifficulty.medium);
    });
  });
}
