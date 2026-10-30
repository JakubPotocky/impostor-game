import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';

/// Setup card for optional rule variants that change how a round plays.
class GameVariantsCard extends ConsumerWidget {
  const GameVariantsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(gameSetupProvider);
    final notifier = ref.read(gameSetupProvider.notifier);

    return SetupCard(
      icon: Icons.casino_rounded,
      iconColor: Colors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Variants',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          _VariantSwitch(
            title: 'Undercover',
            subtitle: 'Impostors get a similar decoy word and don\'t know '
                'they are impostors',
            value: setup.undercoverMode,
            onChanged: notifier.setUndercoverMode,
          ),
          _VariantSwitch(
            title: 'Mystery Impostors',
            subtitle: setup.impostorCount > 1
                ? 'Anywhere from 1 to ${setup.impostorCount} impostors — '
                    'nobody knows how many'
                : 'Raise the impostor count to make it a mystery',
            value: setup.mysteryImpostors,
            onChanged: notifier.setMysteryImpostors,
          ),
          _VariantSwitch(
            title: 'Last Chance',
            subtitle: 'A caught impostor can still win by guessing the word',
            value: setup.lastChanceGuess,
            onChanged: notifier.setLastChanceGuess,
          ),
        ],
      ),
    );
  }
}

class _VariantSwitch extends StatelessWidget {
  const _VariantSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
