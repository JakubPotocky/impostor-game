import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/validators.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/core/word_picker_service.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/players/players_notifier.dart';
import 'package:impostor/features/role_reveal/role_reveal_screen.dart';
import 'package:impostor/features/themes/themes_notifier.dart';

/// Provider for the word picker, persists across the session.
final wordPickerServiceProvider = Provider<WordPickerService>((ref) {
  return WordPickerService();
});

/// Pre-game review screen: shows players summary, impostor count, and start.
class PreGameScreen extends ConsumerWidget {
  const PreGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersState = ref.watch(playersProvider);
    final setupState = ref.watch(gameSetupProvider);
    final themesAsync = ref.watch(themesProvider);

    final playerCount = playersState.count;
    final players = playersState.players;
    final impostorCount = setupState.impostorCount;
    final selectedThemes = setupState.selectedThemes
        .where((name) => name != 'Team Pairs')
        .toList();

    final hasEnoughPlayers = Validators.hasEnoughPlayers(playerCount,
        minimum: AppConstants.minPlayers);
    final validImpostors =
        Validators.isValidImpostorCount(impostorCount, playerCount);
    final hasThemes = selectedThemes.isNotEmpty;
    final canStart = hasEnoughPlayers && validImpostors && hasThemes;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Setup'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // --- Players summary ---
          StaggeredFadeIn(
            delay: 0,
            child: SetupCard(
              icon: Icons.people_alt_rounded,
              iconColor: colorScheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Players',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$playerCount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!hasEnoughPlayers)
                    Text(
                      'Need at least ${AppConstants.minPlayers} players — go back to add more',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 12,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: players.map((name) {
                        return Chip(
                          label:
                              Text(name, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
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
                    'Change language for this round before starting',
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
                      final isSelected = setupState.language == entry.key;
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
                    'Toggle one or more themes for this round',
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
                          .where((name) => name != 'Team Pairs')
                          .toList();
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
                  if (!hasThemes)
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

          // --- Impostor count ---
          StaggeredFadeIn(
            delay: 3,
            child: SetupCard(
              icon: Icons.masks_rounded,
              iconColor: Colors.redAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Impostors',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleButton(
                        icon: Icons.remove,
                        onPressed: impostorCount > 1
                            ? () {
                                ref
                                    .read(gameSetupProvider.notifier)
                                    .setImpostorCount(impostorCount - 1);
                              }
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Text(
                            '$impostorCount',
                            key: ValueKey(impostorCount),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                        ),
                      ),
                      CircleButton(
                        icon: Icons.add,
                        onPressed:
                            playerCount > 0 && impostorCount < playerCount - 1
                                ? () {
                                    ref
                                        .read(gameSetupProvider.notifier)
                                        .setImpostorCount(impostorCount + 1);
                                  }
                                : null,
                      ),
                    ],
                  ),
                  if (!validImpostors && playerCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          'Must be fewer than total players',
                          style:
                              TextStyle(color: colorScheme.error, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // --- Discussion timer ---
          StaggeredFadeIn(
            delay: 4,
            child: SetupCard(
              icon: Icons.timer_rounded,
              iconColor: Colors.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discussion Timer',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: setupState.timerEnabled,
                        onChanged: (v) => ref
                            .read(gameSetupProvider.notifier)
                            .setTimerEnabled(v),
                      ),
                    ],
                  ),
                  if (setupState.timerEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleButton(
                          icon: Icons.remove,
                          onPressed: setupState.timerMinutes > 1
                              ? () => ref
                                  .read(gameSetupProvider.notifier)
                                  .setTimerMinutes(setupState.timerMinutes - 1)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Text(
                              '${setupState.timerMinutes} min',
                              key: ValueKey(setupState.timerMinutes),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                            ),
                          ),
                        ),
                        CircleButton(
                          icon: Icons.add,
                          onPressed: setupState.timerMinutes < 5
                              ? () => ref
                                  .read(gameSetupProvider.notifier)
                                  .setTimerMinutes(setupState.timerMinutes + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Hints toggle ---
          StaggeredFadeIn(
            delay: 5,
            child: SetupCard(
              icon: Icons.lightbulb_rounded,
              iconColor: Colors.amber,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hints',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Show a clue with the revealed word',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: setupState.hintsEnabled,
                    onChanged: (v) =>
                        ref.read(gameSetupProvider.notifier).setHintsEnabled(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Sudden Death toggle ---
          StaggeredFadeIn(
            delay: 6,
            child: SetupCard(
              icon: Icons.local_fire_department,
              iconColor: Colors.red,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sudden Death',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'One wrong vote and innocents lose',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: setupState.suddenDeathEnabled,
                    onChanged: (v) => ref
                        .read(gameSetupProvider.notifier)
                        .setSuddenDeathEnabled(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // --- Start game button ---
          StaggeredFadeIn(
            delay: 7,
            child: StartGameButton(
              canStart: canStart,
              onPressed: () =>
                  _startGame(context, ref, themesAsync.valueOrNull),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _startGame(
    BuildContext context,
    WidgetRef ref,
    dynamic themesState,
  ) {
    if (themesState == null) return;
    final allPlayers = ref.read(playersProvider).players;
    final setup = ref.read(gameSetupProvider);
    final enabledThemes =
        setup.selectedThemes.where((name) => name != 'Team Pairs').toList();
    if (enabledThemes.isEmpty) return;

    final random = Random();

    // Check for "j999" trigger — remove that player and force blank round.
    final hasJ999 = allPlayers.any((p) => p == 'j999');
    final players = hasJ999
        ? allPlayers.where((p) => p != 'j999').toList()
        : List<String>.from(allPlayers);

    if (players.length < AppConstants.minPlayers) return;

    // ~8 % random chance for blank round, or forced by j999 trigger.
    final isBlankRound = hasJ999 || random.nextInt(12) == 0;

    final theme = enabledThemes[random.nextInt(enabledThemes.length)];
    final language = setup.language;
    final englishWords = themesState.getEnglishWords(theme);
    if (englishWords.isEmpty) return;

    final wordPicker = ref.read(wordPickerServiceProvider);
    final wordIndex = wordPicker.pickWordIndex(
      theme: theme,
      wordCount: englishWords.length,
      random: random,
    );

    final translatedWords = themesState.getWords(theme, language);
    final word = wordIndex < translatedWords.length
        ? translatedWords[wordIndex]
        : englishWords[wordIndex];

    List<RoleAssignment> assignments;
    if (isBlankRound) {
      // Blank round: everyone is the impostor — nobody sees the word.
      assignments = players
          .map((name) => RoleAssignment(
                playerName: name,
                isImpostor: true,
              ))
          .toList();
    } else {
      const roleService = RoleAssignmentService();
      assignments = roleService.assignRoles(
        players: players,
        impostorCount: setup.impostorCount,
        word: word,
        random: random,
      );
    }

    Navigator.of(context).push(
      createSlideRoute(
        RoleRevealScreen(
          assignments: assignments,
          word: word,
          themeName: theme,
          hintsEnabled: setup.hintsEnabled,
          timerSeconds: setup.timerEnabled ? setup.timerMinutes * 60 : 0,
          isBlankRound: isBlankRound,
          reducedMotion: setup.reducedMotion,
          suddenDeathEnabled: setup.suddenDeathEnabled,
        ),
      ),
    );
  }
}
