import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/feedback_service.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';

/// [FeedbackService] honouring the user's sound and haptics settings.
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  final (sound, haptics) = ref.watch(
    gameSetupProvider.select((s) => (s.soundEnabled, s.hapticsEnabled)),
  );
  return FeedbackService(soundEnabled: sound, hapticsEnabled: haptics);
});
