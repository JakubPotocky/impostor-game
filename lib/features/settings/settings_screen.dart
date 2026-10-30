import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/data/theme_word.dart';
import 'package:impostor/features/game_setup/difficulty_filter_card.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/theme_selection.dart';
import 'package:impostor/features/onboarding/onboarding_screen.dart';
import 'package:impostor/features/settings/backup_screen.dart';
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
                  minLines: 4,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Words — one per line',
                    hintText: 'Red: Roses\nBlue: Sky\nGreen',
                    helperText: 'Add an impostor hint after a colon',
                    helperMaxLines: 2,
                    alignLabelWithHint: true,
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
                final words = parseWordList(wordsCtrl.text);
                if (name.isNotEmpty && words.isNotEmpty) {
                  ref.read(themesProvider.notifier).addCategory(name, words);
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
          // --- Appearance: system / light / dark ---
          StaggeredFadeIn(
            delay: 0,
            child: SetupCard(
              icon: switch (setupState.themeMode) {
                ThemeMode.system => Icons.brightness_auto_rounded,
                ThemeMode.light => Icons.light_mode_rounded,
                ThemeMode.dark => Icons.dark_mode_rounded,
              },
              iconColor: setupState.themeMode == ThemeMode.light
                  ? Colors.amber
                  : Colors.indigo,
              child: Column(
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
                    setupState.themeMode == ThemeMode.system
                        ? "Follows your phone's light/dark setting"
                        : 'Always ${setupState.themeMode.name}',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {setupState.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => ref
                        .read(gameSetupProvider.notifier)
                        .setThemeMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Reduced motion ---
          StaggeredFadeIn(
            delay: 1,
            child: SetupCard(
              icon: Icons.motion_photos_off_rounded,
              iconColor: Colors.blueGrey,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reduced Motion',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        setupState.reducedMotion
                            ? 'Simpler transitions'
                            : 'Full cinematic transitions',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: setupState.reducedMotion,
                    onChanged: (v) => ref
                        .read(gameSetupProvider.notifier)
                        .setReducedMotion(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Sound, haptics and reveal privacy ---
          StaggeredFadeIn(
            delay: 1,
            child: _SwitchCard(
              icon: setupState.soundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              iconColor: Colors.cyan,
              title: 'Sound',
              subtitle: setupState.soundEnabled
                  ? 'Click sounds on votes and timers'
                  : 'Muted',
              value: setupState.soundEnabled,
              onChanged: (v) =>
                  ref.read(gameSetupProvider.notifier).setSoundEnabled(v),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredFadeIn(
            delay: 1,
            child: _SwitchCard(
              icon: setupState.hapticsEnabled
                  ? Icons.vibration_rounded
                  : Icons.phone_android_rounded,
              iconColor: Colors.pink,
              title: 'Vibration',
              subtitle: setupState.hapticsEnabled
                  ? 'Vibrate on reveals, votes and wins'
                  : 'Off — handy for quiet rooms',
              value: setupState.hapticsEnabled,
              onChanged: (v) =>
                  ref.read(gameSetupProvider.notifier).setHapticsEnabled(v),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredFadeIn(
            delay: 1,
            child: _SwitchCard(
              icon: Icons.fingerprint_rounded,
              iconColor: Colors.green,
              title: 'Hold to Peek',
              subtitle: setupState.holdToReveal
                  ? 'Roles show only while you hold the screen'
                  : 'Tap once to reveal your role',
              value: setupState.holdToReveal,
              onChanged: (v) =>
                  ref.read(gameSetupProvider.notifier).setHoldToReveal(v),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredFadeIn(
            delay: 1,
            child: _SwitchCard(
              icon: Icons.family_restroom_rounded,
              iconColor: Colors.lightGreen,
              title: 'Family Mode',
              subtitle: setupState.familyMode
                  ? 'Mature themes are hidden and never picked'
                  : 'Hide mature themes when playing with kids',
              value: setupState.familyMode,
              onChanged: (v) =>
                  ref.read(gameSetupProvider.notifier).setFamilyMode(v),
            ),
          ),
          const SizedBox(height: 16),

          // --- Language selector ---
          StaggeredFadeIn(
            delay: 2,
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
            delay: 3,
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
                      final themeNames =
                          selectableThemes(themesState, setupState);
                      if (themeNames.isEmpty) {
                        return const Text('No themes available');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ThemeQuickActions(available: themeNames),
                          Wrap(
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
                                  fontWeight: isOn
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
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

          // --- Word difficulty filter ---
          const StaggeredFadeIn(
            delay: 3,
            child: DifficultyFilterCard(),
          ),
          const SizedBox(height: 16),

          // --- Manage themes (browse words, add category) ---
          StaggeredFadeIn(
            delay: 4,
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
                    'Browse words, edit hints and difficulty, or add your own',
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
                      final themeNames = themesState.themeNames
                          .where((t) =>
                              !setupState.familyMode ||
                              !AppConstants.matureThemes.contains(t))
                          .toList();
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
          const SizedBox(height: 16),

          // --- Data & help ---
          StaggeredFadeIn(
            delay: 5,
            child: SetupCard(
              icon: Icons.help_outline_rounded,
              iconColor: Colors.blueGrey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data & Help',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.backup_rounded),
                    title: const Text('Backup & Restore'),
                    subtitle: const Text('Keep your history safe or move it '
                        'to a new phone'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.of(context)
                        .push(createSlideRoute(const BackupScreen())),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.school_rounded),
                    title: const Text('Replay Tutorial'),
                    subtitle: const Text('Walk through how to play again'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.of(context).push(
                      createSlideRoute(
                        OnboardingScreen(
                          onComplete: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
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

/// A settings card with a title, a status line and a switch.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // The whole card toggles (not just the small switch) and is announced as
    // a single control by screen readers.
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: _card(context),
      ),
    );
  }

  Widget _card(BuildContext context) {
    return SetupCard(
      icon: icon,
      iconColor: iconColor,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
