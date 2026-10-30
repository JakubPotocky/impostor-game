import 'dart:math';

/// Generic questions anyone can answer about their word, for when the table
/// runs out of ideas. They work for any word in any theme, and are vague
/// enough that an impostor can bluff an answer.
abstract final class DiscussionPrompts {
  static const List<String> all = [
    'Where would you usually find it?',
    'Is it bigger or smaller than a microwave?',
    'What color comes to mind first?',
    'Would you give it as a gift?',
    'Is it more of a weekday or a weekend thing?',
    'What sound does it make — if any?',
    'Would a child know what it is?',
    'Is it more fun alone or with friends?',
    'How does it make you feel, in one word?',
    'Could you fit it in your pocket?',
    'Is it something you\'d see in a movie?',
    'Would your grandparents have used it?',
    'Is it expensive?',
    'What season does it remind you of?',
    'Is it something you do, or something you have?',
    'Would it be allowed on a plane?',
    'Which room of a house does it belong in?',
    'Hot or cold?',
    'Is it something people argue about?',
    'Would it make a good tattoo?',
    'Is it popular right now, or a classic?',
    'Would you find it in the city or the countryside?',
    'What would a dog think of it?',
    'Rate it from 1 to 10 — and say why.',
    'What\'s the first word that rhymes with it in your head? (Don\'t say it!)',
    'Is it more useful in the morning or at night?',
    'Could it break if you dropped it?',
    'Would it be in a museum in 100 years?',
    'What\'s its biggest enemy?',
    'If it were a person, what job would it have?',
  ];

  /// A random prompt, never the same as [previous] (when possible).
  static String next(Random random, {String? previous}) {
    final options = previous == null
        ? all
        : all.where((p) => p != previous).toList(growable: false);
    return options[random.nextInt(options.length)];
  }
}
