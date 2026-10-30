import 'package:flutter/material.dart';

/// Emoji + color identity for players, so names are recognisable at a glance
/// in a crowded voting grid.
///
/// Every name gets a deterministic default — the same name always gets the
/// same face and color, on every phone — so most players never need to pick
/// one. A chosen emoji overrides the default (see AvatarsNotifier).
abstract final class PlayerAvatars {
  /// Curated set: animals and faces that read clearly at small sizes.
  static const List<String> emojis = [
    '🦊', '🐼', '🐸', '🐙', '🦁', '🐯', '🐨', '🐵', '🦄', '🐲',
    '🐧', '🦉', '🐢', '🦋', '🐝', '🐳', '🦖', '🐺', '🦝', '🐰',
    '🐻', '🐷', '🐮', '🐔', '🦀', '🦩', '🦜', '🐬', '🦔', '🐹',
    '😎', '🤠', '👻', '🤖', '👽', '🎃', '🧙', '🥷', '🧛', '🤡',
  ];

  /// Distinct, mid-tone colors that work on light and dark surfaces.
  static const List<Color> colors = [
    Color(0xFFE57373), Color(0xFFF06292), Color(0xFFBA68C8),
    Color(0xFF7986CB), Color(0xFF4FC3F7), Color(0xFF4DB6AC),
    Color(0xFF81C784), Color(0xFFDCE775), Color(0xFFFFB74D),
    Color(0xFFA1887F),
  ];

  static String defaultEmoji(String name) =>
      emojis[_stableHash(name) % emojis.length];

  /// Uses the low bits of the hash, so names that differ only in their last
  /// character ("Player 1", "Player 2", …) still get different colors.
  static Color colorFor(String name) =>
      colors[_stableHash(name) % colors.length];

  /// String hash that, unlike [String.hashCode], is guaranteed identical
  /// across runs and devices — LAN guests must see the same defaults.
  static int _stableHash(String s) {
    var h = 0;
    for (final unit in s.trim().toLowerCase().codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return h;
  }
}
