import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/data/custom_theme_repository.dart';
import 'package:impostor/data/theme_repository.dart';
import 'package:impostor/data/theme_word.dart';
import 'package:impostor/features/themes/themes_state.dart';
import 'package:impostor/features/themes/word_difficulty_notifier.dart';

/// Notifier that loads and caches theme data.
class ThemesNotifier extends AsyncNotifier<ThemesState> {
  late final ThemeRepository _repo;
  late final CustomThemeRepository _customRepo;

  @override
  Future<ThemesState> build() async {
    _repo = ref.read(themeRepositoryProvider);
    _customRepo = ref.read(customThemeRepositoryProvider);
    return _load();
  }

  Future<ThemesState> _load() async {
    final bundled = await _repo.loadThemes();
    final custom = _customRepo.getCustomThemes();
    return ThemesState(
      themes: _merge(bundled, custom),
      customThemeNames: custom.keys.toSet(),
      isLoading: false,
    );
  }

  /// Merges bundled and custom themes. Custom themes override bundled ones with
  /// the same name, and new custom themes are appended.
  ThemeCatalog _merge(ThemeCatalog bundled, ThemeCatalog custom) {
    return copyThemeCatalog(bundled)..addAll(copyThemeCatalog(custom));
  }

  // ---------------------------------------------------------------------------
  // Custom theme CRUD
  // ---------------------------------------------------------------------------

  /// Adds a brand new custom category with English words only.
  Future<void> addCategory(String name, List<ThemeWord> englishWords) async {
    final custom = _customRepo.getCustomThemes();
    custom[name] = {'en': List.of(englishWords)};
    await _customRepo.saveCustomThemes(custom);
    await _reload();
  }

  /// Adds a word (with optional hint) to [category] under [language].
  Future<void> addWord(String category, String language, ThemeWord word) async {
    final custom = _customRepo.getCustomThemes();
    final langMap = _ensureCustomCopy(custom, category) ?? (custom[category] = {});
    langMap.putIfAbsent(language, () => []).add(word);
    await _customRepo.saveCustomThemes(custom);
    await _reload();
  }

  /// Removes a word at [index] from [category] under [language].
  Future<void> removeWord(String category, String language, int index) async {
    final custom = _customRepo.getCustomThemes();
    final words = _ensureCustomCopy(custom, category)?[language];
    if (words == null || index < 0 || index >= words.length) return;
    final removed = words.removeAt(index);
    await _customRepo.saveCustomThemes(custom);
    if (language == 'en') {
      await ref
          .read(wordDifficultyProvider.notifier)
          .remove(WordKey(theme: category, englishWord: removed.text));
    }
    await _reload();
  }

  /// Replaces the word at [index] in [category] under [language].
  ///
  /// Renaming an English word carries its difficulty rating over, since the
  /// English text is the word's identity for ratings.
  Future<void> editWord(
    String category,
    String language,
    int index,
    ThemeWord newWord,
  ) async {
    final custom = _customRepo.getCustomThemes();
    final words = _ensureCustomCopy(custom, category)?[language];
    if (words == null || index < 0 || index >= words.length) return;
    final previous = words[index];
    words[index] = newWord;
    await _customRepo.saveCustomThemes(custom);
    if (language == 'en' && previous.text != newWord.text) {
      await ref.read(wordDifficultyProvider.notifier).rename(
            WordKey(theme: category, englishWord: previous.text),
            WordKey(theme: category, englishWord: newWord.text),
          );
    }
    await _reload();
  }

  /// Deletes an entire custom category.
  Future<void> deleteCategory(String name) async {
    final custom = _customRepo.getCustomThemes();
    custom.remove(name);
    await _customRepo.saveCustomThemes(custom);
    await _reload();
    // A deleted override of a bundled theme falls back to the bundled words,
    // whose ratings must survive; only drop ratings if the theme is gone.
    if (state.valueOrNull?.themes.containsKey(name) == false) {
      await ref.read(wordDifficultyProvider.notifier).removeTheme(name);
    }
  }

  /// Returns the custom copy of [category], first copying the bundled version
  /// into [custom] if the user hasn't edited it before. Null if the category
  /// exists nowhere.
  Map<String, List<ThemeWord>>? _ensureCustomCopy(
    ThemeCatalog custom,
    String category,
  ) {
    if (!custom.containsKey(category)) {
      final current = state.valueOrNull?.themes[category];
      if (current == null) return null;
      custom[category] = copyThemeCatalog({category: current})[category]!;
    }
    return custom[category];
  }

  Future<void> _reload() async {
    state = AsyncData(await _load());
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
