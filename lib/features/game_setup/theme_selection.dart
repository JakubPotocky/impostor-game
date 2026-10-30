import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/game_setup/round_factory.dart';
import 'package:impostor/features/themes/themes_state.dart';

/// Themes that can be picked for a normal round right now: never Team Pairs
/// (Team mode's word pairs), and no mature themes while Family mode is on.
List<String> selectableThemes(ThemesState themes, GameSetupState setup) {
  return [
    for (final name in themes.themeNames)
      if (name != RoundFactory.teamPairsTheme &&
          !(setup.familyMode && AppConstants.matureThemes.contains(name)))
        name,
  ];
}

/// "All", "None" and "Surprise me" shortcuts above a theme chip list.
class ThemeQuickActions extends ConsumerWidget {
  const ThemeQuickActions({super.key, required this.available});

  /// The themes the shortcuts choose from (see [selectableThemes]).
  final List<String> available;

  /// How many themes "Surprise me" turns on.
  static const int surpriseCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameSetupProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('All'),
            onPressed: () => notifier.setSelectedThemes(available),
          ),
          ActionChip(
            avatar: const Icon(Icons.remove_done_rounded, size: 18),
            label: const Text('None'),
            onPressed: () => notifier.setSelectedThemes(const []),
          ),
          ActionChip(
            avatar: const Icon(Icons.casino_rounded, size: 18),
            label: const Text('Surprise me'),
            onPressed: () => notifier.setSelectedThemes(
              (List.of(available)..shuffle(Random()))
                  .take(surpriseCount)
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
