import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/presets_notifier.dart';
import 'package:impostor/features/game_setup/round_preset.dart';

/// Setup card for saving the current round settings as a named preset and
/// applying saved ones with a single tap.
class PresetCard extends ConsumerWidget {
  const PresetCard({super.key});

  static const int maxNameLength = 24;

  Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
    final presets = ref.read(presetsProvider);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _PresetNameDialog(
        existingNames: presets.map((p) => p.name).toSet(),
      ),
    );
    if (name == null) return;
    await ref.read(presetsProvider.notifier).saveCurrent(name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved preset "$name"')));
  }

  void _apply(BuildContext context, WidgetRef ref, RoundPreset preset) {
    ref.read(presetsProvider.notifier).apply(preset);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Loaded "${preset.name}"')));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RoundPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Delete "${preset.name}"? Your current settings stay '
            'as they are.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(presetsProvider.notifier).delete(preset.name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);
    final setup = ref.watch(gameSetupProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SetupCard(
      icon: Icons.bookmarks_rounded,
      iconColor: Colors.indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Presets',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            presets.isEmpty
                ? 'Save these settings to load them in one tap next time'
                : 'Tap to load · long-press to delete',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in presets)
                GestureDetector(
                  onLongPress: () => _confirmDelete(context, ref, preset),
                  child: ChoiceChip(
                    label: Text(preset.name),
                    selected: preset.matches(setup),
                    onSelected: (_) => _apply(context, ref, preset),
                    selectedColor: colorScheme.primaryContainer,
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Save current'),
                onPressed: () => _saveCurrent(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks for a preset name; warns (but allows) overwriting an existing one.
class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog({required this.existingNames});

  final Set<String> existingNames;

  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  void _submit() {
    if (_name.isEmpty) return;
    Navigator.of(context).pop(_name);
  }

  @override
  Widget build(BuildContext context) {
    final overwrites = widget.existingNames.contains(_name);
    return AlertDialog(
      title: const Text('Save Preset'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: PresetCard.maxNameLength,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Preset name',
          hintText: 'e.g. Friday night',
          helperText: overwrites ? 'Replaces the existing preset' : null,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.isEmpty ? null : _submit,
          child: Text(overwrites ? 'Replace' : 'Save'),
        ),
      ],
    );
  }
}
