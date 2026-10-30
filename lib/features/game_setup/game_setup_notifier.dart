import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/data/settings_repository.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/game_setup/round_preset.dart';

/// Notifier for game configuration (impostor count, selected theme).
class GameSetupNotifier extends Notifier<GameSetupState> {
  late final SettingsRepository _repo;

  @override
  GameSetupState build() {
    _repo = ref.read(settingsRepositoryProvider);
    return GameSetupState(
      impostorCount: _repo.getImpostorCount(),
      selectedThemes: _repo.getSelectedThemes(),
      language: _repo.getLanguage(),
      timerEnabled: _repo.getTimerEnabled(),
      timerMinutes: _repo.getTimerMinutes(),
      hintsEnabled: _repo.getHintsEnabled(),
      themeVisibilityMode: ThemeVisibilityMode
          .values[_repo.getThemeVisibilityMode().clamp(0, 2)],
      reducedMotion: _repo.getReducedMotion(),
      suddenDeathEnabled: _repo.getSuddenDeathEnabled(),
      themeMode: _repo.getThemeMode(),
      allowedDifficulties: _repo.getAllowedDifficulties(),
      soundEnabled: _repo.getSoundEnabled(),
      hapticsEnabled: _repo.getHapticsEnabled(),
      holdToReveal: _repo.getHoldToReveal(),
      undercoverMode: _repo.getUndercoverMode(),
      mysteryImpostors: _repo.getMysteryImpostors(),
      lastChanceGuess: _repo.getLastChanceGuess(),
      familyMode: _repo.getFamilyMode(),
    );
  }

  void setImpostorCount(int count) {
    state = state.copyWith(impostorCount: count);
    _repo.saveImpostorCount(count);
  }

  void toggleTheme(String theme) {
    final current = List<String>.from(state.selectedThemes);
    if (current.contains(theme)) {
      current.remove(theme);
    } else {
      current.add(theme);
    }
    state = state.copyWith(selectedThemes: current);
    _repo.saveSelectedThemes(current);
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
    _repo.saveLanguage(language);
  }

  void setTimerEnabled(bool enabled) {
    state = state.copyWith(timerEnabled: enabled);
    _repo.saveTimerEnabled(enabled);
  }

  void setTimerMinutes(int minutes) {
    state = state.copyWith(timerMinutes: minutes.clamp(1, 5));
    _repo.saveTimerMinutes(minutes.clamp(1, 5));
  }

  void setHintsEnabled(bool enabled) {
    state = state.copyWith(hintsEnabled: enabled);
    _repo.saveHintsEnabled(enabled);
  }

  void setThemeVisibilityMode(ThemeVisibilityMode mode) {
    state = state.copyWith(themeVisibilityMode: mode);
    _repo.saveThemeVisibilityMode(mode.index);
  }

  void setReducedMotion(bool enabled) {
    state = state.copyWith(reducedMotion: enabled);
    _repo.saveReducedMotion(enabled);
  }

  void setSuddenDeathEnabled(bool enabled) {
    state = state.copyWith(suddenDeathEnabled: enabled);
    _repo.saveSuddenDeathEnabled(enabled);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _repo.saveThemeMode(mode);
  }

  void setUndercoverMode(bool enabled) {
    state = state.copyWith(undercoverMode: enabled);
    _repo.saveUndercoverMode(enabled);
  }

  void setMysteryImpostors(bool enabled) {
    state = state.copyWith(mysteryImpostors: enabled);
    _repo.saveMysteryImpostors(enabled);
  }

  void setLastChanceGuess(bool enabled) {
    state = state.copyWith(lastChanceGuess: enabled);
    _repo.saveLastChanceGuess(enabled);
  }

  /// Turning Family mode on also deselects mature themes, so nothing hidden
  /// stays silently selected.
  void setFamilyMode(bool enabled) {
    final themes = enabled
        ? state.selectedThemes
            .where((t) => !AppConstants.matureThemes.contains(t))
            .toList()
        : state.selectedThemes;
    state = state.copyWith(familyMode: enabled, selectedThemes: themes);
    _repo
      ..saveFamilyMode(enabled)
      ..saveSelectedThemes(themes);
  }

  /// Replaces the whole theme selection (e.g. "All", "None", "Surprise me").
  void setSelectedThemes(List<String> themes) {
    state = state.copyWith(selectedThemes: List.unmodifiable(themes));
    _repo.saveSelectedThemes(themes);
  }

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
    _repo.saveSoundEnabled(enabled);
  }

  void setHapticsEnabled(bool enabled) {
    state = state.copyWith(hapticsEnabled: enabled);
    _repo.saveHapticsEnabled(enabled);
  }

  void setHoldToReveal(bool enabled) {
    state = state.copyWith(holdToReveal: enabled);
    _repo.saveHoldToReveal(enabled);
  }

  /// Applies a preset's round settings and persists them, so they stay in
  /// effect after a restart like any manually chosen setting.
  void applyPreset(RoundPreset preset) {
    state = preset.applyTo(state);
    _repo
      ..saveImpostorCount(state.impostorCount)
      ..saveSelectedThemes(state.selectedThemes)
      ..saveLanguage(state.language)
      ..saveTimerEnabled(state.timerEnabled)
      ..saveTimerMinutes(state.timerMinutes)
      ..saveHintsEnabled(state.hintsEnabled)
      ..saveThemeVisibilityMode(state.themeVisibilityMode.index)
      ..saveSuddenDeathEnabled(state.suddenDeathEnabled)
      ..saveAllowedDifficulties(state.allowedDifficulties)
      ..saveUndercoverMode(state.undercoverMode)
      ..saveMysteryImpostors(state.mysteryImpostors)
      ..saveLastChanceGuess(state.lastChanceGuess);
  }

  /// Toggles whether words of [difficulty] can be picked.
  ///
  /// Refuses to deselect the last remaining difficulty — an empty filter
  /// would leave no playable words. Returns whether the toggle was applied.
  bool toggleDifficulty(WordDifficulty difficulty) {
    final current = Set<WordDifficulty>.of(state.allowedDifficulties);
    if (current.contains(difficulty)) {
      if (current.length == 1) return false;
      current.remove(difficulty);
    } else {
      current.add(difficulty);
    }
    state = state.copyWith(allowedDifficulties: current);
    _repo.saveAllowedDifficulties(current);
    return true;
  }
}

/// Provider for [SettingsRepository].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Provider for [GameSetupNotifier].
final gameSetupProvider =
    NotifierProvider<GameSetupNotifier, GameSetupState>(GameSetupNotifier.new);
