import 'package:flutter/material.dart';

/// Colors for private role reveals.
///
/// Deliberately the same for every role: the screen's glow lights up the
/// holder's face, so a distinct impostor color would give them away to
/// everyone else at the table. Role is conveyed by text and icon only.
abstract final class RevealPalette {
  static Color get accent => Colors.green.shade400;
  static Color get accentSoft => Colors.green.shade300;
  static Color get shimmer => Colors.green.shade200;
}
