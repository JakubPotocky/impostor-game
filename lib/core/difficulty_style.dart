import 'package:flutter/material.dart';
import 'package:impostor/core/word_difficulty.dart';

/// Visual treatment for each [WordDifficulty], shared by every screen that
/// shows or edits ratings.
extension WordDifficultyStyle on WordDifficulty {
  Color get color => switch (this) {
        WordDifficulty.unset => Colors.blueGrey,
        WordDifficulty.easy => Colors.green,
        WordDifficulty.medium => Colors.orange,
        WordDifficulty.hard => Colors.red,
      };

  IconData get icon => switch (this) {
        WordDifficulty.unset => Icons.help_outline_rounded,
        WordDifficulty.easy => Icons.sentiment_satisfied_rounded,
        WordDifficulty.medium => Icons.sentiment_neutral_rounded,
        WordDifficulty.hard => Icons.sentiment_very_dissatisfied_rounded,
      };
}

/// Compact pill showing a word's difficulty.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({super.key, required this.difficulty});

  final WordDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        difficulty.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
