import 'dart:math';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/core/word_picker_service.dart';
import 'package:impostor/core/word_weighting.dart';
import 'package:impostor/data/theme_word.dart';
import 'package:impostor/data/word_vote_repository.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/game_setup/round_factory.dart';
import 'package:impostor/features/game_setup/round_preset.dart';
import 'package:impostor/features/themes/themes_state.dart';

void main() {
  group('WordWeighting', () {
    test('unvoted words keep the base weight', () {
      expect(WordWeighting.fromVotes(), WordWeighting.baseWeight);
    });

    test('likes raise and dislikes lower the weight, within bounds', () {
      expect(WordWeighting.fromVotes(likes: 2), greaterThan(1));
      expect(WordWeighting.fromVotes(dislikes: 2), lessThan(1));
      expect(WordWeighting.fromVotes(dislikes: 100), WordWeighting.minWeight);
      expect(WordWeighting.fromVotes(likes: 100), WordWeighting.maxWeight);
    });
  });

  group('weighted word picking', () {
    test('a heavily liked word is picked first far more often', () {
      final random = Random(7);
      var likedFirst = 0;
      const trials = 2000;
      for (var t = 0; t < trials; t++) {
        final picked = WordPickerService().pickFromCandidates(
          theme: 'T',
          candidates: [0, 1, 2, 3],
          random: random,
          weightOf: (i) => i == 0 ? WordWeighting.maxWeight : 1,
        );
        if (picked == 0) likedFirst++;
      }
      // Uniform would be 25 %; weight 3 of 6 total is 50 %.
      expect(likedFirst / trials, closeTo(0.5, 0.05));
    });

    test('weighting never brings back an already-used word', () {
      final picker = WordPickerService();
      final random = Random(1);
      final picked = {
        for (var i = 0; i < 3; i++)
          picker.pickFromCandidates(
            theme: 'T',
            candidates: [0, 1, 2],
            random: random,
            weightOf: (i) => i == 0 ? 3 : 0.2,
          ),
      };
      expect(picked, {0, 1, 2});
    });

    test('round factory pools votes for the shown and English word', () {
      final themes = ThemesState(isLoading: false, themes: {
        'Animals': {
          'en': const [ThemeWord('Lion'), ThemeWord('Otter')],
          'sk': const [ThemeWord('Lev'), ThemeWord('Vydra')],
        },
      });
      final random = Random(3);
      var lev = 0;
      for (var t = 0; t < 600; t++) {
        final result = const RoundFactory().build(
          players: const ['A', 'B', 'C'],
          enabledThemes: const ['Animals'],
          impostorCount: 1,
          language: 'sk',
          allowedDifficulties: GameSetupState.allDifficulties,
          themes: themes,
          difficulties: const WordDifficultyMap(),
          // Fresh picker each time so only the first pick is measured.
          wordPicker: WordPickerService(),
          random: random,
          votes: const {
            'Lev': WordVote(likes: 10),
            'Otter': WordVote(dislikes: 10),
          },
        );
        if ((result as RoundReady).round.word == 'Lev') lev++;
      }
      // Weights 3.0 vs 0.2 → Lev ≈ 94 % of first picks.
      expect(lev / 600, greaterThan(0.85));
    });
  });

  group('RoundPreset', () {
    const state = GameSetupState(
      impostorCount: 2,
      selectedThemes: ['Food', 'Animals'],
      language: 'de',
      timerEnabled: true,
      timerMinutes: 4,
      hintsEnabled: true,
      themeVisibilityMode: ThemeVisibilityMode.everyone,
      suddenDeathEnabled: false,
      allowedDifficulties: {WordDifficulty.easy, WordDifficulty.medium},
      themeMode: ThemeMode.light,
    );

    test('round-trips through JSON and matches its source state', () {
      final preset = RoundPreset.fromJson(
          RoundPreset.fromState('Friday', state).toJson());
      expect(preset.name, 'Friday');
      expect(preset.matches(state), isTrue);
    });

    test('applying keeps device preferences untouched', () {
      final preset = RoundPreset.fromState('Friday', state);
      const other =
          GameSetupState(themeMode: ThemeMode.dark, holdToReveal: true);
      final applied = preset.applyTo(other);
      expect(preset.matches(applied), isTrue);
      expect(applied.themeMode, ThemeMode.dark);
      expect(applied.holdToReveal, isTrue);
    });

    test('older saves without newer fields fall back to defaults', () {
      final preset = RoundPreset.fromJson(const {'name': 'Old'});
      expect(preset.allowedDifficulties, GameSetupState.allDifficulties);
      expect(preset.themeVisibilityMode,
          const GameSetupState().themeVisibilityMode);
    });

    test('changing a setting means the preset no longer matches', () {
      final preset = RoundPreset.fromState('Friday', state);
      expect(preset.matches(state.copyWith(impostorCount: 3)), isFalse);
    });
  });
}
