import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rules'),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '60 sec'),
              Tab(text: 'Detailed'),
              Tab(text: 'Variants'),
              Tab(text: 'Connecting'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _QuickRules(colorScheme: colorScheme),
            _DetailedRules(colorScheme: colorScheme),
            const _VariantsGuide(),
            _ConnectingGuide(colorScheme: colorScheme),
          ],
        ),
      ),
    );
  }
}

class _QuickRules extends StatelessWidget {
  const _QuickRules({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _RuleCard(
          title: 'Goal',
          lines: [
            'Innocents: find all impostors.',
            'Impostors: survive and blend in.',
          ],
        ),
        _RuleCard(
          title: 'Round Flow',
          lines: [
            '1) Reveal roles privately.',
            '2) Discuss without saying the exact word.',
            '3) Vote to eliminate one suspect.',
          ],
        ),
        _RuleCard(
          title: 'Win Conditions',
          lines: [
            'Innocents win when all impostors are eliminated.',
            'Impostors win when impostors >= innocents.',
          ],
        ),
      ],
    );
  }
}

class _DetailedRules extends StatelessWidget {
  const _DetailedRules({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _RuleCard(
          title: 'Core Objective',
          lines: [
            'Players receive hidden identities each round.',
            'Innocents get the secret word; impostors do not.',
            'Use discussion clues to identify impostors.',
          ],
        ),
        _RuleCard(
          title: 'Setup Rules',
          lines: [
            'Minimum players: 3.',
            'Impostor count must be lower than total players.',
            'Select at least one theme and a language.',
          ],
        ),
        _RuleCard(
          title: 'Voting Logic',
          lines: [
            'One elimination per vote action.',
            'Undo can reverse the last elimination before game end.',
            'Blank round ends immediately after first elimination.',
          ],
        ),
        _RuleCard(
          title: 'Normal Mode',
          lines: [
            'All innocents share one secret word.',
            'Impostors improvise based on discussion context.',
          ],
        ),
        _RuleCard(
          title: 'Team Mode',
          lines: [
            'Two innocent teams get similar but different words.',
            'Exactly one impostor has no word.',
            'After discussion, players sort everyone into Team A/B.',
            'The team containing the impostor loses.',
          ],
        ),
        _RuleCard(
          title: 'Sudden Death',
          lines: [
            'Activates late game when remaining players are low.',
            'Once active, one wrong elimination of an innocent ends the game in impostor favor.',
          ],
        ),
        _RuleCard(
          title: 'Edge Cases',
          lines: [
            'Blank round: everyone is effectively impostor; ends on first elimination.',
            'If timer is on, discussion is time-bounded but voting still decides outcome.',
          ],
        ),
      ],
    );
  }
}

class _ConnectingGuide extends StatelessWidget {
  const _ConnectingGuide({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _RuleCard(
          title: 'Two Ways to Join a LAN Game',
          lines: [
            'Everyone must be on the same network as the host.',
            'If the host is sharing mobile data as a hotspot, connect to that hotspot instead of home Wi-Fi.',
            'App players and browser players can play in the same game together.',
          ],
        ),
        _RuleCard(
          title: 'A) With the App Installed',
          lines: [
            'Everyone installs Impostor on their own phone.',
            'The host opens LAN Multiplayer and taps Host a Game.',
            'Each guest opens LAN Multiplayer and taps Join a Game — nearby lobbies appear automatically.',
            'Guest taps the lobby, then picks which player they are from the list.',
            'When the host starts the game, roles are revealed on each guest\'s own phone.',
          ],
        ),
        _RuleCard(
          title: 'B) From Chrome, Safari, or Any Browser — No App Needed',
          lines: [
            'The host creates a lobby as usual; the Host Lobby screen shows a join link and a QR code.',
            'Each guest scans the QR code with their phone camera, or types the link into their browser.',
            'A simple page opens — no install, no account. Guest enters a name and picks which player they are.',
            'When the host starts the game, that guest\'s phone reveals their role right there in the browser.',
            'Closing the browser tab leaves the game — reopen the same link to rejoin.',
          ],
        ),
        _RuleCard(
          title: 'Troubleshooting',
          lines: [
            'Nothing found when joining: double-check every phone is on the exact same Wi-Fi or hotspot.',
            'QR code won\'t scan: type the link shown under the code instead.',
            'A guest\'s screen looks frozen: they can reopen the link or reopen the app to rejoin.',
          ],
        ),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $line'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional rules and play aids, all switchable in Game Setup or Settings.
class _VariantsGuide extends StatelessWidget {
  const _VariantsGuide();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _RuleCard(
          title: 'Undercover',
          lines: [
            'Impostors get a similar word from the same theme instead of '
                'nothing — and are not told they are impostors.',
            'Everyone believes they hold the real word, so listen for the '
                'one answer that is slightly off.',
            'The decoy word is revealed at the end.',
          ],
        ),
        _RuleCard(
          title: 'Mystery Impostors',
          lines: [
            'The impostor count becomes a maximum: each round has anywhere '
                'from 1 up to that many.',
            'Nobody knows how many remain — the vote screen only shows how '
                'many have been caught.',
          ],
        ),
        _RuleCard(
          title: 'Last Chance',
          lines: [
            'When the last impostor is voted out, the impostors get one guess '
                'at the secret word.',
            'Guess right and the impostors win after all. The table judges '
                'the guess.',
          ],
        ),
        _RuleCard(
          title: 'Hints & Word Difficulty',
          lines: [
            'With Hints on, impostors see a clue related to the word.',
            'After each game, rate how hard the word was; filter by '
                'difficulty in Game Setup.',
            'Liked words come up more often, disliked ones less.',
          ],
        ),
        _RuleCard(
          title: 'Play Aids',
          lines: [
            'Hold to Peek: roles show only while you hold the screen.',
            'Discussion questions (💡 on the vote screen) give the table a '
                'question to answer about their word.',
            'The timer can be paused or extended by 30 seconds.',
            'Shuffle the player list to randomise reveal and speaking order.',
          ],
        ),
        _RuleCard(
          title: "Tonight's Standings",
          lines: [
            'Games since the app was opened count towards tonight\'s scores.',
            'An impostor win is worth 2 points, an innocent win 1.',
            'Start a new session from the end screen at any time.',
          ],
        ),
        _RuleCard(
          title: 'Family Mode',
          lines: [
            'Hides mature themes everywhere and never picks them. Turn it on '
                'in Settings before playing with kids.',
          ],
        ),
      ],
    );
  }
}
