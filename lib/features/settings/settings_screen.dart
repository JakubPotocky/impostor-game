import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/themes/theme_detail_screen.dart';
import 'package:impostor/features/themes/theme_export_screen.dart';
import 'package:impostor/features/themes/themes_notifier.dart';

/// Screen for language and theme settings (persistent configuration).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final wordsCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    hintText: 'e.g. Colors',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: wordsCtrl,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Words (comma-separated)',
                    hintText: 'Red, Blue, Green, ...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final rawWords = wordsCtrl.text
                    .split(',')
                    .map((w) => w.trim())
                    .where((w) => w.isNotEmpty)
                    .toList();
                if (name.isNotEmpty && rawWords.isNotEmpty) {
                  ref.read(themesProvider.notifier).addCategory(name, rawWords);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupState = ref.watch(gameSetupProvider);
    final themesAsync = ref.watch(themesProvider);
    final selectedThemes = setupState.selectedThemes;
    final language = setupState.language;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // --- Dark / Light mode ---
          StaggeredFadeIn(
            delay: 0,
            child: SetupCard(
              icon: setupState.darkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              iconColor: setupState.darkMode ? Colors.indigo : Colors.amber,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        setupState.darkMode ? 'Dark mode' : 'Light mode',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: setupState.darkMode,
                    onChanged: (v) =>
                        ref.read(gameSetupProvider.notifier).setDarkMode(v),
                    thumbIcon: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Icon(Icons.dark_mode_rounded, size: 18);
                      }
                      return const Icon(Icons.light_mode_rounded, size: 18);
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Language selector ---
          StaggeredFadeIn(
            delay: 1,
            child: SetupCard(
              icon: Icons.translate_rounded,
              iconColor: Colors.teal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Word Language',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The secret word will be shown in this language',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.languageLabels.entries.map((entry) {
                      final isSelected = language == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: isSelected,
                        onSelected: (_) {
                          ref
                              .read(gameSetupProvider.notifier)
                              .setLanguage(entry.key);
                        },
                        selectedColor: colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Theme toggles ---
          StaggeredFadeIn(
            delay: 2,
            child: SetupCard(
              icon: Icons.category_rounded,
              iconColor: Colors.orange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Themes',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toggle themes on — a word will be picked from one',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  themesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (themesState) {
                      final themeNames = themesState.themeNames;
                      if (themeNames.isEmpty) {
                        return const Text('No themes available');
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: themeNames.map((name) {
                          final isOn = selectedThemes.contains(name);
                          return FilterChip(
                            avatar: Icon(themeIcon(name), size: 18),
                            label: Text(name),
                            selected: isOn,
                            onSelected: (_) {
                              ref
                                  .read(gameSetupProvider.notifier)
                                  .toggleTheme(name);
                            },
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.onPrimaryContainer,
                            labelStyle: TextStyle(
                              fontWeight:
                                  isOn ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  if (!setupState.hasThemes)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Enable at least one theme',
                        style:
                            TextStyle(color: colorScheme.error, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Manage themes (browse words, add category) ---
          StaggeredFadeIn(
            delay: 3,
            child: SetupCard(
              icon: Icons.edit_note_rounded,
              iconColor: Colors.deepPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Themes',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse, add, edit or delete words in each category',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  themesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (themesState) {
                      final themeNames = themesState.themeNames;
                      return Column(
                        children: [
                          ...themeNames.map((name) {
                            final wordCount =
                                themesState.getEnglishWords(name).length;
                            final isCustom = themesState.isCustom(name);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                themeIcon(name),
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  if (isCustom) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withAlpha(40),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Custom',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.deepPurple),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '$wordCount words',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withAlpha(120),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCustom)
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          size: 18, color: colorScheme.error),
                                      onPressed: () => _confirmDeleteCategory(
                                          context, ref, name),
                                      tooltip: 'Delete category',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  const Icon(Icons.chevron_right, size: 20),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  createSlideRoute(
                                    ThemeDetailScreen(themeName: name),
                                  ),
                                );
                              },
                            );
                          }),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showAddCategoryDialog(context, ref),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Category'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  createSlideRoute(
                                    const ThemeExportScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.import_export_rounded,
                                  size: 18),
                              label: const Text('Export / Import Themes'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(
      BuildContext context, WidgetRef ref, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text('Remove the "$name" category? This cannot be undone.'),
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
                ref.read(themesProvider.notifier).deleteCategory(name);
                // Also remove from selected themes if it was enabled.
                final selected = ref.read(gameSetupProvider).selectedThemes;
                if (selected.contains(name)) {
                  ref.read(gameSetupProvider.notifier).toggleTheme(name);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
