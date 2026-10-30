import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/player_avatar.dart';
import 'package:impostor/features/players/avatars_notifier.dart';

/// Round emoji badge identifying [name].
class PlayerAvatar extends ConsumerWidget {
  const PlayerAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(avatarsProvider.select((m) => m[name]));
    final color = PlayerAvatars.colorFor(name);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(60),
          border: Border.all(color: color.withAlpha(160), width: 1.5),
        ),
        child: Text(
          chosen ?? PlayerAvatars.defaultEmoji(name),
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}

/// Bottom sheet for picking [name]'s emoji.
Future<void> showAvatarPicker(
  BuildContext context,
  WidgetRef ref,
  String name,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final current = ref.read(avatarsProvider.notifier).emojiFor(name);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Avatar for $name',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final emoji in PlayerAvatars.emojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ref.read(avatarsProvider.notifier).setEmoji(name, emoji);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: emoji == current
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .primaryContainer,
                              )
                            : null,
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(avatarsProvider.notifier).setEmoji(name, null);
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Use default'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
