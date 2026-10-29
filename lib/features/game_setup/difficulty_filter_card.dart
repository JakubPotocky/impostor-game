import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/difficulty_style.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/round_factory.dart';
import 'package:impostor/features/themes/themes_notifier.dart';
import 'package:impostor/features/themes/word_difficulty_notifier.dart';

/// Setup card for choosing which word difficulties can come up.
///
/// Shows how many words in the enabled themes pass the filter, so an
/// over-narrow filter is obvious before trying to start a game.
class DifficultyFilterCard extends ConsumerWidget {
  const DifficultyFilterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(gameSetupProvider);
    final themes = ref.watch(themesProvider).valueOrNull;
    final difficulties = ref.watch(wordDifficultyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final playableThemes = setup.selectedThemes
        .where((t) => t != RoundFactory.teamPairsTheme)
        .toList();
    int? eligible;
    var total = 0;
    if (themes != null) {
      eligible = 0;
      for (final theme in playableThemes) {
        total += themes.getEntries(theme, 'en').length;
        eligible = eligible! +
            RoundFactory.eligibleWordIndices(
              themes: themes,
              theme: theme,
              allowed: setup.allowedDifficulties,
              difficulties: difficulties,
            ).length;
      }
    }

    return SetupCard(
      icon: Icons.speed_rounded,
      iconColor: Colors.deepOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Word Difficulty',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Only pick words with these ratings. Rate words after each game.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WordDifficulty.values.map((d) {
              final isOn = setup.allowedDifficulties.contains(d);
              return FilterChip(
                avatar: Icon(d.icon, size: 18, color: d.color),
                label: Text(d.label),
                selected: isOn,
                showCheckmark: false,
                selectedColor: d.color.withAlpha(45),
                side: BorderSide(
                  color: isOn ? d.color.withAlpha(140) : colorScheme.outline,
                ),
                labelStyle: TextStyle(
                  fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  final applied =
                      ref.read(gameSetupProvider.notifier).toggleDifficulty(d);
                  if (!applied) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(
                        content: Text('Keep at least one difficulty selected'),
                      ));
                  }
                },
              );
            }).toList(),
          ),
          if (eligible != null && playableThemes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              eligible == 0
                  ? 'No words in your themes match this filter'
                  : '$eligible of $total words in your themes match',
              style: TextStyle(
                fontSize: 12,
                color: eligible == 0
                    ? colorScheme.error
                    : colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
