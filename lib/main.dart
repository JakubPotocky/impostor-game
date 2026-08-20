import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/data/custom_theme_repository.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/data/player_repository.dart';
import 'package:impostor/data/settings_repository.dart';
import 'package:impostor/data/word_vote_repository.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/home/home_screen.dart';
import 'package:impostor/features/onboarding/onboarding_screen.dart';
import 'package:impostor/features/players/players_notifier.dart';
import 'package:impostor/features/themes/themes_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Hive.
  await Hive.initFlutter();

  // Initialise repositories.
  final playerRepo = PlayerRepository();
  await playerRepo.init();

  final settingsRepo = SettingsRepository();
  await settingsRepo.init();

  final customThemeRepo = CustomThemeRepository();
  await customThemeRepo.init();

  final wordVoteRepo = WordVoteRepository();
  await wordVoteRepo.init();

  final gameHistoryRepo = GameHistoryRepository();
  await gameHistoryRepo.init();

  final hasSeenTutorial = settingsRepo.getHasSeenTutorial();

  runApp(
    ProviderScope(
      overrides: [
        playerRepositoryProvider.overrideWithValue(playerRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        customThemeRepositoryProvider.overrideWithValue(customThemeRepo),
        wordVoteRepositoryProvider.overrideWithValue(wordVoteRepo),
        gameHistoryRepositoryProvider.overrideWithValue(gameHistoryRepo),
      ],
      child: ImpostorApp(showOnboarding: !hasSeenTutorial),
    ),
  );
}

class ImpostorApp extends ConsumerWidget {
  const ImpostorApp({super.key, this.showOnboarding = false});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(
      gameSetupProvider.select((s) => s.darkMode),
    );
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: showOnboarding ? _OnboardingWrapper() : const HomeScreen(),
    );
  }
}

/// Wraps the onboarding screen so it navigates to HomeScreen on completion.
class _OnboardingWrapper extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingScreen(
      onComplete: () {
        // Persist that the user has seen the tutorial.
        final repo = ref.read(settingsRepositoryProvider);
        repo.saveHasSeenTutorial(true);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        );
      },
    );
  }
}
