import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/backup_service.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/features/changelog/changelog_screen.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/presets_notifier.dart';
import 'package:impostor/features/players/avatars_notifier.dart';
import 'package:impostor/features/players/groups_notifier.dart';
import 'package:impostor/features/players/players_notifier.dart';
import 'package:impostor/features/themes/themes_notifier.dart';
import 'package:impostor/features/themes/word_difficulty_notifier.dart';

/// Backs up all app data (players, history, themes, ratings, presets,
/// settings) to the clipboard, and restores it — e.g. on a new phone.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  String? _status;
  bool _isError = false;
  bool _busy = false;

  void _setStatus(String message, {bool isError = false}) {
    setState(() {
      _status = message;
      _isError = isError;
    });
  }

  Map<String, int> _currentSummary() => {
        'players': ref.read(playersProvider).count,
        'games': ref.read(gameHistoryRepositoryProvider).getGames().length,
        'customThemes': ref.read(themesProvider).valueOrNull?.customThemeNames
                .length ??
            0,
        'presets': ref.read(presetsProvider).length,
        'ratedWords': ref.read(wordDifficultyProvider).ratedCount,
      };

  Future<void> _export() async {
    final text = ref.read(backupServiceProvider).export(
          appVersion: ChangelogScreen.currentVersion,
          exportedAt: DateTime.now(),
          summary: _currentSummary(),
        );
    await Clipboard.setData(ClipboardData(text: text));
    _setStatus('Backup copied to the clipboard. Paste it somewhere safe — '
        'a note, an email to yourself, or a chat.');
  }

  Future<void> _restore() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null || text.isEmpty) {
      _setStatus('Copy a backup to the clipboard first.', isError: true);
      return;
    }

    final service = ref.read(backupServiceProvider);
    final ParsedBackup backup;
    try {
      backup = service.parse(text);
    } on BackupFormatException catch (e) {
      _setStatus(e.message, isError: true);
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmRestoreDialog(backup: backup),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await service.restore(backup);
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    // Everything cached from storage must be reloaded from the new data.
    ref
      ..invalidate(gameSetupProvider)
      ..invalidate(playersProvider)
      ..invalidate(themesProvider)
      ..invalidate(wordDifficultyProvider)
      ..invalidate(presetsProvider)
      ..invalidate(avatarsProvider)
      ..invalidate(groupsProvider);
    _setStatus('Backup restored.');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Everything is stored only on this phone. Uninstalling the app or '
            'clearing its data erases it, so keep a backup.',
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(160),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.cloud_upload_rounded,
            title: 'Back Up',
            description: 'Copies players, groups, avatars, game history, '
                'achievements, custom themes, word ratings, presets and '
                'settings.',
            buttonLabel: 'Copy Backup',
            onPressed: _busy ? null : _export,
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Restore',
            description: 'Copy a backup, then tap below. Replaces the data '
                'on this phone — you can review the backup first.',
            buttonLabel: 'Restore from Clipboard',
            onPressed: _busy ? null : _restore,
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_status case final status?) ...[
            const SizedBox(height: 16),
            _StatusBanner(message: status, isError: _isError),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: color.shade400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Shows what a backup contains before it replaces the current data.
class _ConfirmRestoreDialog extends StatelessWidget {
  const _ConfirmRestoreDialog({required this.backup});

  final ParsedBackup backup;

  static const _labels = {
    'players': 'Players',
    'games': 'Games played',
    'customThemes': 'Custom themes',
    'presets': 'Presets',
    'ratedWords': 'Rated words',
  };

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(backup.exportedAt);
    return AlertDialog(
      title: const Text('Restore Backup?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Made on $date with version ${backup.appVersion}.'),
          const SizedBox(height: 12),
          for (final MapEntry(:key, value: label) in _labels.entries)
            if (backup.summary[key] case final count?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(label), Text('$count')],
                ),
              ),
          const SizedBox(height: 12),
          Text(
            'This replaces the data on this phone and cannot be undone.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Restore'),
        ),
      ],
    );
  }
}
