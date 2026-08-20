import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/core/validators.dart';

void main() {
  group('GameSetupState configuration validation', () {
    test('default state has 1 impostor, no themes, and English language', () {
      const state = GameSetupState();
      expect(state.impostorCount, 1);
      expect(state.selectedThemes, isEmpty);
      expect(state.hasThemes, false);
      expect(state.language, 'en');
    });

    test('cannot start with no theme selected', () {
      const state = GameSetupState(impostorCount: 1);
      expect(state.hasThemes, false);
    });

    test('cannot start with too many impostors', () {
      const playerCount = 3;
      const state =
          GameSetupState(impostorCount: 3, selectedThemes: ['Animals']);
      final valid =
          Validators.isValidImpostorCount(state.impostorCount, playerCount);
      expect(valid, false);
    });

    test('valid configuration passes validation', () {
      const playerCount = 5;
      const state = GameSetupState(impostorCount: 2, selectedThemes: ['Food']);
      final validImpostors =
          Validators.isValidImpostorCount(state.impostorCount, playerCount);
      final enoughPlayers = Validators.hasEnoughPlayers(playerCount);
      final hasThemes = state.hasThemes;

      expect(validImpostors, true);
      expect(enoughPlayers, true);
      expect(hasThemes, true);
    });

    test('copyWith creates new instance with updated values', () {
      const original = GameSetupState(impostorCount: 1);
      final updated = original.copyWith(
        impostorCount: 3,
        selectedThemes: ['Sports', 'Food'],
        language: 'sk',
      );
      expect(updated.impostorCount, 3);
      expect(updated.selectedThemes, ['Sports', 'Food']);
      expect(updated.language, 'sk');
      // Original unchanged.
      expect(original.impostorCount, 1);
      expect(original.selectedThemes, isEmpty);
      expect(original.language, 'en');
    });

    test('language defaults to en', () {
      const state = GameSetupState();
      expect(state.language, 'en');
    });

    test('multiple themes can be selected', () {
      const state =
          GameSetupState(selectedThemes: ['Animals', 'Food', 'Sports']);
      expect(state.hasThemes, true);
      expect(state.selectedThemes.length, 3);
    });
  });
}
