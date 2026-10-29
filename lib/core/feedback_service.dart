import 'package:flutter/services.dart';

/// Provides sound effect and haptic feedback methods.
///
/// Uses system sounds and haptics — no external audio packages needed.
/// Each channel can be muted independently (see Settings).
class FeedbackService {
  const FeedbackService({this.soundEnabled = true, this.hapticsEnabled = true});

  final bool soundEnabled;
  final bool hapticsEnabled;

  /// Light haptic on generic taps.
  Future<void> lightTap() => _haptic(HapticFeedback.lightImpact);

  /// Haptic for role reveal.
  ///
  /// Identical for every role on purpose: a stronger buzz for impostors can
  /// be felt or heard by the people sitting next to the phone.
  Future<void> roleReveal() => _haptic(HapticFeedback.mediumImpact);

  /// Heavy haptic on vote/kill.
  Future<void> voteKill() async {
    await _haptic(HapticFeedback.heavyImpact);
    await click();
  }

  /// Vibration pattern for victory.
  Future<void> victory() async {
    await _haptic(HapticFeedback.mediumImpact);
    await Future.delayed(const Duration(milliseconds: 120));
    await _haptic(HapticFeedback.mediumImpact);
    await Future.delayed(const Duration(milliseconds: 120));
    await _haptic(HapticFeedback.heavyImpact);
  }

  /// Click sound.
  Future<void> click() async {
    if (soundEnabled) await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _haptic(Future<void> Function() impact) async {
    if (hapticsEnabled) await impact();
  }
}
