import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/core/word_picker_service.dart';
import 'package:impostor/data/theme_word.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/game_setup/round_factory.dart';
import 'package:impostor/features/themes/themes_state.dart';

const _players = ['Alice', 'Bob', 'Charlie', 'Diana'];

final _themes = ThemesState(
  isLoading: false,
  themes: {
    'Animals': {
      'en': const [
        ThemeWord('Lion', hint: 'Mane'),
        ThemeWord('Penguin', hint: 'Tuxedo'),
        ThemeWord('Otter'), // no hint
      ],
      'sk': const [
        ThemeWord('Lev', hint: 'Hriva'),
        ThemeWord('Tučniak', hint: 'Frak'),
        // Shorter than English on purpose.
      ],
    },
    'Team Pairs': {
      'en': const [ThemeWord('Cat|Dog')],
    },
  },
);

RoundBuildResult _build({
  List<String> players = _players,
  List<String> enabledThemes = const ['Animals'],
  int impostorCount = 1,
  String language = 'en',
  Set<WordDifficulty> allowed = GameSetupState.allDifficulties,
  WordDifficultyMap difficulties = const WordDifficultyMap(),
  WordPickerService? picker,
  int seed = 1,
}) {
  return const RoundFactory().build(
    players: players,
    enabledThemes: enabledThemes,
    impostorCount: impostorCount,
    language: language,
    allowedDifficulties: allowed,
    themes: _themes,
    difficulties: difficulties,
    wordPicker: picker ?? WordPickerService(),
    random: Random(seed),
  );
}

GameRound _ready(RoundBuildResult result) => switch (result) {
      RoundReady(:final round) => round,
      RoundUnavailable(:final reason) => fail('Expected a round: $reason'),
    };

String _reason(RoundBuildResult result) => switch (result) {
      RoundUnavailable(:final reason) => reason,
      RoundReady() => fail('Expected the round to be unavailable'),
    };

WordKey _key(String word) => WordKey(theme: 'Animals', englishWord: word);

void main() {
  group('RoundFactory starting player', () {
    test('blank round (everyone impostor) still picks a starter', () {
      // Regression: blank rounds used to skip starter selection entirely.
      final round = _ready(_build(players: [..._players, 'j999']));

      expect(round.isBlankRound, isTrue);
      expect(round.assignments.every((a) => a.isImpostor), isTrue);
      expect(_players, contains(round.startingPlayerName));
    });

    test('normal rounds always pick a starter from the roster', () {
      for (var seed = 0; seed < 50; seed++) {
        final round = _ready(_build(seed: seed));
        expect(_players, contains(round.startingPlayerName));
      }
    });
  });

  group('RoundFactory roster', () {
    test('removes the blank-round trigger from the roster', () {
      final round = _ready(_build(players: [..._players, 'j999']));
      expect(round.assignments.map((a) => a.playerName), _players);
    });

    test('is unavailable with fewer than 3 real players', () {
      expect(_reason(_build(players: ['Alice', 'Bob', 'j999'])),
          contains('at least 3'));
    });

    test('clamps a stale impostor count to players - 1', () {
      for (var seed = 0; seed < 30; seed++) {
        final round = _ready(_build(impostorCount: 10, seed: seed));
        if (round.isBlankRound) continue;
        expect(round.assignments.where((a) => a.isImpostor).length, 3);
      }
    });
  });

  group('RoundFactory word selection', () {
    test('never picks from Team Pairs', () {
      expect(_reason(_build(enabledThemes: ['Team Pairs'])),
          contains('at least one theme'));
      for (var seed = 0; seed < 30; seed++) {
        final round =
            _ready(_build(enabledThemes: ['Animals', 'Team Pairs'], seed: seed));
        expect(round.themeName, 'Animals');
      }
    });

    test('only picks words whose difficulty is allowed', () {
      final difficulties = WordDifficultyMap({
        _key('Lion').storageKey: WordDifficulty.easy,
        _key('Penguin').storageKey: WordDifficulty.hard,
      });
      for (var seed = 0; seed < 30; seed++) {
        final round = _ready(_build(
          allowed: {WordDifficulty.easy},
          difficulties: difficulties,
          seed: seed,
        ));
        expect(round.word, 'Lion');
      }
    });

    test('unrated words count as unset for filtering', () {
      final difficulties = WordDifficultyMap({
        _key('Lion').storageKey: WordDifficulty.easy,
        _key('Penguin').storageKey: WordDifficulty.easy,
      });
      final round = _ready(_build(
        allowed: {WordDifficulty.unset},
        difficulties: difficulties,
      ));
      expect(round.word, 'Otter');
    });

    test('is unavailable when no word matches the difficulty filter', () {
      expect(_reason(_build(allowed: {WordDifficulty.hard})),
          contains('difficulty'));
    });

    test('word key uses the English word whatever the language', () {
      final picker = WordPickerService();
      final seen = <String>{};
      for (var seed = 0; seed < 3; seed++) {
        final round = _ready(_build(language: 'sk', picker: picker, seed: seed));
        seen.add(round.word);
        expect(['Lion', 'Penguin', 'Otter'],
            contains(round.wordKey.englishWord));
      }
      // Index 2 has no Slovak translation, so it falls back to English.
      expect(seen, {'Lev', 'Tučniak', 'Otter'});
    });
  });

  group('RoundFactory impostor hint', () {
    test("uses the word's own hint in the selected language", () {
      final difficulties =
          WordDifficultyMap({_key('Lion').storageKey: WordDifficulty.easy});
      final round = _ready(_build(
        language: 'sk',
        allowed: {WordDifficulty.easy},
        difficulties: difficulties,
      ));
      expect(round.word, 'Lev');
      expect(round.impostorHint, 'Hriva');
    });

    test('falls back to a related theme word when the word has no hint', () {
      final round = _ready(_build(allowed: {WordDifficulty.unset},
          difficulties: WordDifficultyMap({
            _key('Lion').storageKey: WordDifficulty.easy,
            _key('Penguin').storageKey: WordDifficulty.easy,
          })));
      expect(round.word, 'Otter');
      expect(['Lion', 'Penguin'], contains(round.impostorHint));
    });
  });
}
