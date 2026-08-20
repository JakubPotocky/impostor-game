import 'dart:math';

/// Picks a single-word hint related to the secret word from the same theme list.
String? pickImpostorHintWord({
  required List<String> themeWords,
  required String secretWord,
  required Random random,
}) {
  final secret = _normalize(secretWord);
  if (themeWords.isEmpty || secret.isEmpty) return null;

  final candidates = themeWords.where((w) {
    final normalized = _normalize(w);
    return normalized.isNotEmpty && normalized != secret;
  }).toList();

  if (candidates.isEmpty) return null;

  final picked = candidates[random.nextInt(candidates.length)].trim();
  if (picked.isEmpty) return null;

  // Force a single-word clue.
  return picked.split(RegExp(r'\s+')).first;
}

String _normalize(String input) {
  return input.trim().toLowerCase();
}
