import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/custom_theme_repository.dart';
import 'package:impostor/data/theme_repository.dart';
import 'package:impostor/features/themes/themes_state.dart';

/// Notifier that loads and caches theme data.
class ThemesNotifier extends AsyncNotifier<ThemesState> {
  late final ThemeRepository _repo;
  late final CustomThemeRepository _customRepo;

  @override
  Future<ThemesState> build() async {
    _repo = ref.read(themeRepositoryProvider);
    _customRepo = ref.read(customThemeRepositoryProvider);
    final bundled = await _repo.loadThemes();
    final custom = _customRepo.getCustomThemes();
    final merged = _merge(bundled, custom);
    return ThemesState(
      themes: merged,
      customThemeNames: custom.keys.toSet(),
      isLoading: false,
    );
  }

  /// Merges bundled and custom themes. Custom themes override bundled ones with
  /// the same name, and new custom themes are appended.
  Map<String, Map<String, List<String>>> _merge(
    Map<String, Map<String, List<String>>> bundled,
    Map<String, Map<String, List<String>>> custom,
  ) {
    final result = Map<String, Map<String, List<String>>>.from(
      bundled.map((k, v) => MapEntry(
          k,
          Map<String, List<String>>.from(
            v.map((lang, words) => MapEntry(lang, List<String>.from(words))),
          ))),
    );
    // Overlay custom themes on top.
    for (final entry in custom.entries) {
      result[entry.key] = Map<String, List<String>>.from(
        entry.value
            .map((lang, words) => MapEntry(lang, List<String>.from(words))),
      );
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Custom theme CRUD
  // ---------------------------------------------------------------------------

  /// Adds a brand new custom category with English words only.
  Future<void> addCategory(String name, List<String> englishWords) async {
    final custom = _customRepo.getCustomThemes();
    custom[name] = {'en': englishWords};
    await _customRepo.saveCustomThemes(custom);
    await _reload();
  }

  /// Adds a word to [category] under [language].
  Future<void> addWord(String category, String language, String word) async {
    final custom = _customRepo.getCustomThemes();
    // If the category isn't in custom yet, copy it from current state.
    if (!custom.containsKey(category)) {
      final current = state.valueOrNull?.themes[category];
      if (current != null) {
        custom[category] = current
            .map((lang, words) => MapEntry(lang, List<String>.from(words)));
      } else {
        custom[category] = {};
      }
    }
    custom[category]!.putIfAbsent(language, () => []);
    custom[category]![language]!.add(word);
    await _customRepo.saveCustomThemes(custom);
    await _reload();
  }

  /// Removes a word at [index] from [category] under [language].
  Future<void> removeWord(String category, String language, int index) async {
    final custom = _customRepo.getCustomThemes();
    if (!custom.containsKey(category)) {
      final current = state.valueOrNull?.themes[category];
      if (current != null) {
        custom[category] = current
            .map((lang, words) => MapEntry(lang, List<String>.from(words)));
      } else {
        return;
      }
    }
    final words = custom[category]?[language];
    if (words == null || index < 0 || index >= words.length) return;
    words.removeAt(index);
    await _customRepo.saveCustomThemes(custom);
    await _reload();
  }

  /// Edits a word at [index] in [category] under [language].
  Future<void> editWord(
      String category, String language, int index, String newWord) async {
    final custom = _customRepo.getCustomThemes();
    if (!custom.containsKey(category)) {
      final current = state.valueOrNull?.themes[category];
      if (current != null) {
        custom[category] = current
            .map((lang, words) => MapEntry(lang, List<String>.from(words)));
      } else {
        return;
      }
    }
    final words = custom[category]?[language];
    if (words == null || index < 0 || index >= words.length) return;
    words[index] = newWord;
    await _customRepo.saveCustomThemes(custom);
    await _reload();
  }

  /// Deletes an entire custom category.
  Future<void> deleteCategory(String name) async {
    final custom = _customRepo.getCustomThemes();
    custom.remove(name);
    await _customRepo.saveCustomThemes(custom);
    await _reload();
  }

  Future<void> _reload() async {
    final bundled = await _repo.loadThemes();
    final custom = _customRepo.getCustomThemes();
    final merged = _merge(bundled, custom);
    state = AsyncData(ThemesState(
      themes: merged,
      customThemeNames: custom.keys.toSet(),
      isLoading: false,
    ));
  }
}

/// Provider for [ThemeRepository].
final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return ThemeRepository();
});

/// Provider for [CustomThemeRepository].
final customThemeRepositoryProvider = Provider<CustomThemeRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Provider for [ThemesNotifier].
final themesProvider =
    AsyncNotifierProvider<ThemesNotifier, ThemesState>(ThemesNotifier.new);
