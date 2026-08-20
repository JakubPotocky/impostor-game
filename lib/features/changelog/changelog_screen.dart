import 'package:flutter/material.dart';

/// In-app changelog showing version history.
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  /// Current app version.
  static const currentVersion = '2.4.0';

  /// Ordered changelog entries (newest first).
  static const List<_ChangelogEntry> _entries = [
    _ChangelogEntry(
      version: '2.4.0',
      date: 'August 20, 2026',
      title: 'Browser Join — No App Required',
      changes: [
        'Guests can now join a LAN game straight from a phone browser — no app install required.',
        'Host Lobby screen shows a join link and QR code; scanning it opens a lightweight join page.',
        'Browser guests pick which player they are and get their own private, distributed role reveal, same as native app players.',
        'App players and browser players can play together in the same lobby.',
        'Added a "Connecting" tab to the Rules page explaining both ways to join: via the app or via a browser.',
      ],
    ),
    _ChangelogEntry(
      version: '2.3.0',
      date: 'August 16, 2026',
      title: 'Polish Update',
      changes: [
        'Refined role reveal flow to keep handoff faster between players.',
        'Hints now support impostor-only clue mode with cleaner in-card layout.',
        'Improved reveal/vote transition smoothness on low-end Android devices.',
        'Small UX pass on buttons, spacing, and result messaging.',
      ],
    ),
    _ChangelogEntry(
      version: '2.2.0',
      date: 'July 31, 2026',
      title: 'LAN Lobby Improvements',
      changes: [
        'LAN host/client lobby flow stabilized for multi-device game nights.',
        'Better reconnect and session-state handling while players join.',
        'Distributed reveal progress indicators improved for host visibility.',
        'Protocol payload cleanup for role assignment sync.',
      ],
    ),
    _ChangelogEntry(
      version: '2.1.0',
      date: 'July 14, 2026',
      title: 'Rules & Clarity',
      changes: [
        'Added dedicated Rules page with quick and detailed tabs.',
        'Updated in-app guidance copy for first-time players and hosts.',
        'Improved navigation from home into setup and rules.',
      ],
    ),
    _ChangelogEntry(
      version: '2.0.0',
      date: 'June 26, 2026',
      title: 'Game Feel Refresh',
      changes: [
        'Major animation and pacing pass across reveal, voting, and end screens.',
        'Introduced reduced motion support to lower visual intensity when preferred.',
        'Refined celebration and dramatic state transitions for clearer round outcomes.',
      ],
    ),
    _ChangelogEntry(
      version: '1.9.0',
      date: 'June 12, 2026',
      title: 'Streaks & History Expansion',
      changes: [
        'Added streak tracking signals and post-game momentum callouts.',
        'Expanded saved game records with richer winner and mode metadata.',
        'Improved stats consistency between normal mode and team mode rounds.',
      ],
    ),
    _ChangelogEntry(
      version: '1.8.0',
      date: 'May 24, 2026',
      title: 'Setup Controls Update',
      changes: [
        'Improved pre-game setup controls for hints, timers, and sudden death toggles.',
        'Better persistence behavior for game options between sessions.',
        'General reliability fixes for round start validation.',
      ],
    ),
    _ChangelogEntry(
      version: '1.7.0',
      date: 'March 27, 2026',
      title: 'Sudden Death & Team Mode',
      changes: [
        'Sudden Death mode — activates dynamically when few players remain. One wrong vote and innocents lose immediately! Features dramatic fullscreen animation.',
        'Team Mode — 2 teams, 2 similar words, 1 impostor. Sort players into teams and the team with the impostor loses.',
        'Added "Team Pairs" theme category with 15 word pairs across 6 languages (Cat|Dog, Sun|Moon, Fire|Ice, etc.).',
        'Dark / Light theme toggle — full Material 3 theme switching in Settings.',
        'Undo last kill — new button on the voting screen to reverse accidental eliminations.',
        'Enhanced voting screen with dramatic sudden death animations, pulsing banners, and red-tinted backgrounds.',
        'In-app changelog — this screen! View all past updates.',
      ],
    ),
    _ChangelogEntry(
      version: '1.6.0',
      date: 'March 26, 2026',
      title: 'Blank Round',
      changes: [
        'Blank Round — randomly (~8% chance) nobody gets the word. Everyone thinks they\'re the impostor!',
        'Special trigger: adding a player named "j999" forces a blank round and removes that player.',
        'Blank rounds end after the first kill with a special amber "Blank Round!" result screen.',
        'End screen adapts to show "All Players" section instead of Impostors/Innocents for blank rounds.',
      ],
    ),
    _ChangelogEntry(
      version: '1.5.0',
      date: 'March 25, 2026',
      title: 'Timer, Stats & Export',
      changes: [
        'Discussion timer — toggle on/off, configurable 1‒5 minutes. Visible countdown bar during voting with color change at ≤30 seconds.',
        'Game History & Stats — track all past games. New Stats screen with Recent Games and Player Stats (win rates) tabs.',
        'Word voting analytics — see top-rated and worst-rated words based on player votes.',
        'Sound effects & haptics — role reveal (heavy double-buzz for impostor, medium for innocent), vote kill, and victory patterns.',
        'Quick rematch — "Play Again" button on the end screen keeps the same players and picks a new word.',
        'Export / Import custom themes — copy themes as JSON to clipboard or paste to import.',
        'Added Game History and Word Analytics buttons to the home screen.',
      ],
    ),
    _ChangelogEntry(
      version: '1.4.0',
      date: 'March 24, 2026',
      title: 'Theme Management',
      changes: [
        'Browse words per category — new Theme Detail screen showing all words in a theme.',
        'Add, edit, and delete words within any category.',
        'Create new custom categories with comma-separated word lists.',
        'Word voting at end of game — like or dislike the secret word after each round.',
        'Custom themes are saved persistently and tagged with a "Custom" badge.',
        'Moved Continue button above the player list for easier access.',
      ],
    ),
    _ChangelogEntry(
      version: '1.3.0',
      date: 'March 23, 2026',
      title: 'Multi-Screen Refactor',
      changes: [
        'Split the monolithic setup into multiple screens: Home, Players, Pre-Game, Settings.',
        'New Home screen with animated hero branding and staggered button entrance.',
        'Onboarding tutorial — 4-page walkthrough explaining how to play, shown on first launch.',
        'Tutorial can be replayed from the "How to Play" button on the home screen.',
        'Persistent "has seen tutorial" flag — onboarding only shows once automatically.',
      ],
    ),
    _ChangelogEntry(
      version: '1.2.0',
      date: 'March 22, 2026',
      title: 'Multi-Language & Themes',
      changes: [
        'Multi-language support — 6 languages: English, Slovenčina, Dansk, Deutsch, Español, 中文.',
        'Theme multi-select — toggle multiple word categories on/off. A random enabled theme is picked each round.',
        'Language selector in settings with choice chips.',
        '7 bundled word categories: Animals, Food, Countries, Sports, Movies, Professions, Objects.',
        'Each theme has 15 words translated into all 6 languages.',
      ],
    ),
    _ChangelogEntry(
      version: '1.1.0',
      date: 'March 21, 2026',
      title: 'Voting & End Screen',
      changes: [
        'Voting screen — 3-column grid of player cards. Tap to eliminate with flip animation.',
        'Win conditions: all impostors eliminated = innocents win, impostors ≥ innocents = impostors win.',
        'End screen showing game result, the secret word, and role breakdown.',
        'Killed players shown with strikethrough and "Eliminated" label.',
        'Exit game confirmation dialog on role reveal and voting screens.',
        'FLAG_SECURE protection during role reveal (prevents screenshots on Android).',
      ],
    ),
    _ChangelogEntry(
      version: '1.0.0',
      date: 'March 20, 2026',
      title: 'Initial Release',
      changes: [
        'Core game loop — add players, configure impostors, reveal roles, play.',
        'Sequential role reveal with fade/scale animations.',
        'Random word picker with no-repeat-until-exhausted logic.',
        'Player management — add, edit, delete, reorder players. Auto-generated names.',
        'Persistent player list and settings via Hive.',
        'Impostor count selector with validation.',
        'Material 3 dark theme with indigo seed color.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("What's New"),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          final isLatest = index == 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isLatest
                    ? BorderSide(
                        color: colorScheme.primary.withAlpha(100), width: 2)
                    : BorderSide.none,
              ),
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLatest
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'v${entry.version}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isLatest
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isLatest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(40),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade400,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          entry.date,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ...entry.changes.map((change) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.circle,
                                size: 6,
                                color: colorScheme.onSurface.withAlpha(100),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                change,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withAlpha(200),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChangelogEntry {
  const _ChangelogEntry({
    required this.version,
    required this.date,
    required this.title,
    required this.changes,
  });

  final String version;
  final String date;
  final String title;
  final List<String> changes;
}
