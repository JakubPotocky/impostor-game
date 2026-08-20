import 'package:flutter/material.dart';

/// Motion tokens and helpers for consistent animation behavior.
class AppMotion {
  AppMotion._();

  static const Curve calmCurve = Curves.easeOutCubic;
  static const Curve dramaticCurve = Curves.elasticOut;
  static const Curve celebrationCurve = Curves.easeOutBack;

  static const Duration setupEnter = Duration(milliseconds: 320);
  static const Duration revealEnter = Duration(milliseconds: 520);
  static const Duration voteCritical = Duration(milliseconds: 1100);
  static const Duration celebration = Duration(milliseconds: 900);

  /// Scales motion for reduced mode while keeping feedback present.
  static Duration resolveDuration(
    Duration normal, {
    required bool reduced,
    double reducedFactor = 0.45,
  }) {
    if (!reduced) return normal;
    final ms = (normal.inMilliseconds * reducedFactor).round();
    return Duration(milliseconds: ms.clamp(120, normal.inMilliseconds));
  }

  static Curve resolveCurve(Curve normal, {required bool reduced}) {
    return reduced ? Curves.easeOut : normal;
  }
}
