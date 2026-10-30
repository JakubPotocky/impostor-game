import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/roster_repository.dart';
import 'package:impostor/features/players/groups_notifier.dart';
import 'package:impostor/features/players/players_notifier.dart';

/// Opens the saved player groups sheet.
Future<void> showGroupsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _GroupsSheet(),
  );
}

class _GroupsSheet extends ConsumerWidget {
  const _GroupsSheet();

  Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Group name',
            hintText: 'e.g. Family',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await ref.read(groupsProvider.notifier).saveCurrent(name);
  }

  void _load(BuildContext context, WidgetRef ref, PlayerGroup group) {
    final previous = ref.read(playersProvider).players;
    ref.read(groupsProvider.notifier).load(group);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Loaded "${group.name}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              ref.read(playersProvider.notifier).setPlayers(previous),
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final hasPlayers = ref.watch(playersProvider).count > 0;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Player Groups',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Save who you play with, then swap the whole list in one tap.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No groups yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final group in groups)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.groups_rounded),
                        title: Text(group.name),
                        subtitle: Text(
                          group.players.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _load(context, ref, group),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: colorScheme.error),
                          tooltip: 'Delete ${group.name}',
                          onPressed: () => ref
                              .read(groupsProvider.notifier)
                              .delete(group.name),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: hasPlayers ? () => _saveCurrent(context, ref) : null,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save current players as a group'),
            ),
          ],
        ),
      ),
    );
  }
}
