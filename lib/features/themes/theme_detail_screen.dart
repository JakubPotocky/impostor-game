import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/difficulty_style.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/data/theme_word.dart';
import 'package:impostor/features/themes/themes_notifier.dart';
import 'package:impostor/features/themes/themes_state.dart';
import 'package:impostor/features/themes/word_difficulty_notifier.dart';

/// Screen for browsing and editing words in a single theme / category.
class ThemeDetailScreen extends ConsumerStatefulWidget {
  const ThemeDetailScreen({super.key, required this.themeName});

  final String themeName;

  @override
  ConsumerState<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends ConsumerState<ThemeDetailScreen> {
  String _selectedLanguage = 'en';
  String _query = '';

  /// Difficulty filter for the list; null shows every word.
  WordDifficulty? _difficultyFilter;

  ThemesNotifier get _themes => ref.read(themesProvider.notifier);

  Future<void> _addWord() async {
    final word = await showDialog<ThemeWord>(
      context: context,
      builder: (_) => const _WordEditorDialog(title: 'Add Word'),
    );
    if (word == null) return;
    await _themes.addWord(widget.themeName, _selectedLanguage, word);
  }

  Future<void> _editWord(int index, ThemeWord current) async {
    final word = await showDialog<ThemeWord>(
      context: context,
      builder: (_) => _WordEditorDialog(title: 'Edit Word', initial: current),
    );
    if (word == null || word == current) return;
    await _themes.editWord(widget.themeName, _selectedLanguage, index, word);
  }

  void _confirmDeleteWord(int index, String word) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Word'),
          content: Text('Remove "$word" from this category?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () {
                _themes.removeWord(widget.themeName, _selectedLanguage, index);
                Navigator.of(ctx).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Indices of words matching the search and difficulty filter. Indices are
  /// kept (rather than the words) because edits and difficulty are addressed
  /// by position in the index-aligned word lists.
  List<int> _visibleIndices(
    ThemesState themesState,
    List<ThemeWord> words,
    WordDifficultyMap difficulties,
  ) {
    final query = _query.trim().toLowerCase();
    return [
      for (var i = 0; i < words.length; i++)
        if (_matchesQuery(words[i], query) &&
            _matchesDifficulty(themesState.wordKeyAt(widget.themeName, i),
                difficulties))
          i,
    ];
  }

  bool _matchesQuery(ThemeWord word, String query) =>
      query.isEmpty ||
      word.text.toLowerCase().contains(query) ||
      (word.hint?.toLowerCase().contains(query) ?? false);

  bool _matchesDifficulty(WordKey? key, WordDifficultyMap difficulties) {
    final filter = _difficultyFilter;
    if (filter == null) return true;
    // Words with no English counterpart can't be rated (or picked).
    return key != null && difficulties.of(key) == filter;
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(themesProvider);
    final difficulties = ref.watch(wordDifficultyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.themeName),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWord,
        tooltip: 'Add word',
        child: const Icon(Icons.add),
      ),
      body: themesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (themesState) {
          final words =
              themesState.getEntries(widget.themeName, _selectedLanguage);
          final visible = _visibleIndices(themesState, words, difficulties);
          final hintCount = words.where((w) => w.hasHint).length;
          final isFiltering =
              _query.trim().isNotEmpty || _difficultyFilter != null;

          return Column(
            children: [
              // Language selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: AppConstants.languageLabels.entries.map((entry) {
                      final isSelected = _selectedLanguage == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedLanguage = entry.key);
                          },
                          selectedColor: colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search words or hints',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // Difficulty filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip(null, 'All'),
                      for (final d in WordDifficulty.values)
                        _filterChip(d, d.label),
                    ],
                  ),
                ),
              ),

              // Word count
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(themeIcon(widget.themeName),
                        size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFiltering
                            ? '${visible.length} of ${words.length} words'
                            : '${words.length} words · $hintCount with hints',
                        style: TextStyle(
                          color: colorScheme.onSurface.withAlpha(150),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Word list
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState(
                        message: words.isEmpty
                            ? 'No words in this language yet'
                            : 'No words match your filters',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final index = visible[i];
                          return _WordTile(
                            index: index,
                            word: words[index],
                            wordKey:
                                themesState.wordKeyAt(widget.themeName, index),
                            difficulties: difficulties,
                            onEdit: () => _editWord(index, words[index]),
                            onDelete: () =>
                                _confirmDeleteWord(index, words[index].text),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(WordDifficulty? difficulty, String label) {
    final isSelected = _difficultyFilter == difficulty;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _difficultyFilter = difficulty),
        avatar: difficulty == null
            ? null
            : Icon(difficulty.icon, size: 16, color: difficulty.color),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _WordTile extends ConsumerWidget {
  const _WordTile({
    required this.index,
    required this.word,
    required this.wordKey,
    required this.difficulties,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final ThemeWord word;

  /// Null when this word has no English counterpart and so can't be rated.
  final WordKey? wordKey;
  final WordDifficultyMap difficulties;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final key = wordKey;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        onTap: onEdit,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: colorScheme.primaryContainer.withAlpha(120),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(word.text),
        subtitle: Text(
          word.hint == null ? 'No hint' : 'Hint: ${word.hint}',
          style: TextStyle(
            fontSize: 12,
            fontStyle: word.hint == null ? FontStyle.italic : null,
            color: colorScheme.onSurface.withAlpha(word.hint == null ? 100 : 150),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (key != null)
              PopupMenuButton<WordDifficulty>(
                tooltip: 'Set difficulty',
                initialValue: difficulties.of(key),
                onSelected: (d) => ref
                    .read(wordDifficultyProvider.notifier)
                    .setDifficulty(key, d),
                itemBuilder: (_) => [
                  for (final d in WordDifficulty.values)
                    PopupMenuItem(
                      value: d,
                      child: Row(
                        children: [
                          Icon(d.icon, size: 18, color: d.color),
                          const SizedBox(width: 8),
                          Text(d.label),
                        ],
                      ),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DifficultyBadge(difficulty: difficulties.of(key)),
                ),
              ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
              onPressed: onDelete,
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.playlist_add,
              size: 56, color: colorScheme.primary.withAlpha(80)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: colorScheme.onSurface.withAlpha(150)),
          ),
        ],
      ),
    );
  }
}

/// Dialog for adding or editing a word and its impostor hint.
///
/// Pops with the resulting [ThemeWord], or null when cancelled.
class _WordEditorDialog extends StatefulWidget {
  const _WordEditorDialog({required this.title, this.initial});

  final String title;
  final ThemeWord? initial;

  @override
  State<_WordEditorDialog> createState() => _WordEditorDialogState();
}

class _WordEditorDialogState extends State<_WordEditorDialog> {
  late final TextEditingController _wordCtrl =
      TextEditingController(text: widget.initial?.text);
  late final TextEditingController _hintCtrl =
      TextEditingController(text: widget.initial?.hint);
  String? _error;

  @override
  void dispose() {
    _wordCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final word = _wordCtrl.text.trim();
    final hint = _hintCtrl.text.trim();
    if (word.isEmpty) {
      setState(() => _error = 'Enter a word');
      return;
    }
    // A hint containing the word would hand it straight to the impostor.
    if (hint.toLowerCase().contains(word.toLowerCase())) {
      setState(() => _error = "The hint can't contain the word itself");
      return;
    }
    Navigator.of(context).pop(ThemeWord(word, hint: hint));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _wordCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Word',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hintCtrl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Hint for impostors (optional)',
              helperText: 'A related clue that doesn\'t give the word away',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initial == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
