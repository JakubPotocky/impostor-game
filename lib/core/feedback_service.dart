import 'package:flutter/services.dart';

/// Provides sound effect and haptic feedback methods.
///
/// Uses system sounds and haptics — no external audio packages needed.
class FeedbackService {
  const FeedbackService();

  /// Light haptic on generic taps.
  Future<void> lightTap() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium haptic for role reveal.
  Future<void> roleReveal({required bool isImpostor}) async {
    if (isImpostor) {
      // Heavy dramatic buzz for impostor.
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } else {
      // Light relief tap for innocent.
      await HapticFeedback.mediumImpact();
    }
  }

  /// Heavy haptic on vote/kill.
  Future<void> voteKill() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  /// Vibration pattern for victory.
  Future<void> victory() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }

  /// Click sound.
  Future<void> click() async {
    await SystemSound.play(SystemSoundType.click);
  }
}
