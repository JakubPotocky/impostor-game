import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/feedback_service.dart';
import 'package:impostor/features/game_setup/feedback_provider.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/players/avatars_notifier.dart';

/// In-memory game setup, so widgets can be tested without Hive.
class FakeGameSetupNotifier extends GameSetupNotifier {
  FakeGameSetupNotifier(this.initial);

  final GameSetupState initial;

  @override
  GameSetupState build() => initial;
}

/// No chosen avatars; everyone gets their default.
class FakeAvatarsNotifier extends AvatarsNotifier {
  @override
  Map<String, String> build() => {};
}

/// Wraps [home] in a MaterialApp with storage-free provider overrides.
Widget testApp(
  Widget home, {
  GameSetupState setup = const GameSetupState(),
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...overrides,
      feedbackServiceProvider.overrideWithValue(
        const FeedbackService(soundEnabled: false, hapticsEnabled: false),
      ),
      gameSetupProvider.overrideWith(() => FakeGameSetupNotifier(setup)),
      avatarsProvider.overrideWith(FakeAvatarsNotifier.new),
    ],
    child: MaterialApp(home: home),
  );
}

/// Pumps fixed frames — screens with looping effects never "settle".
Future<void> pumpFrames(WidgetTester tester, {int count = 10}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
