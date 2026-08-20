import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rules'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: '60 sec'),
              Tab(text: 'Detailed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _QuickRules(colorScheme: colorScheme),
            _DetailedRules(colorScheme: colorScheme),
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
