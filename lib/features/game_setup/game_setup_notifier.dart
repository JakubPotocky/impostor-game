import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/settings_repository.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';

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
      reducedMotion: _repo.getReducedMotion(),
      suddenDeathEnabled: _repo.getSuddenDeathEnabled(),
      darkMode: _repo.getDarkMode(),
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

  void setReducedMotion(bool enabled) {
    state = state.copyWith(reducedMotion: enabled);
    _repo.saveReducedMotion(enabled);
  }

  void setSuddenDeathEnabled(bool enabled) {
    state = state.copyWith(suddenDeathEnabled: enabled);
    _repo.saveSuddenDeathEnabled(enabled);
  }

  void setDarkMode(bool dark) {
    state = state.copyWith(darkMode: dark);
    _repo.saveDarkMode(dark);
  }
}

/// Provider for [SettingsRepository].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Provider for [GameSetupNotifier].
final gameSetupProvider =
    NotifierProvider<GameSetupNotifier, GameSetupState>(GameSetupNotifier.new);
