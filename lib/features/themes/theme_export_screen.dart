import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/features/themes/themes_notifier.dart';

/// Screen for exporting and importing custom theme packs as JSON.
class ThemeExportScreen extends ConsumerStatefulWidget {
  const ThemeExportScreen({super.key});

  @override
  ConsumerState<ThemeExportScreen> createState() => _ThemeExportScreenState();
}

class _ThemeExportScreenState extends ConsumerState<ThemeExportScreen> {
  final _importController = TextEditingController();
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  void _exportToClipboard() {
    final repo = ref.read(customThemeRepositoryProvider);
    final custom = repo.getCustomThemes();
    if (custom.isEmpty) {
      setState(() {
        _statusMessage = 'No custom themes to export';
        _isError = true;
      });
      return;
    }
    final json = const JsonEncoder.withIndent('  ').convert(custom);
    Clipboard.setData(ClipboardData(text: json));
    setState(() {
      _statusMessage = 'Copied ${custom.length} theme(s) to clipboard!';
      _isError = false;
    });
  }

  void _importFromText() {
    final text = _importController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _statusMessage = 'Paste JSON text first';
        _isError = true;
      });
      return;
    }

    try {
      final decoded = json.decode(text) as Map<String, dynamic>;
      final themes = <String, Map<String, List<String>>>{};

      for (final entry in decoded.entries) {
        final langMap = entry.value as Map<String, dynamic>;
        themes[entry.key] = langMap.map(
          (lang, words) =>
              MapEntry(lang, (words as List<dynamic>).cast<String>()),
        );
      }

      if (themes.isEmpty) {
        setState(() {
          _statusMessage = 'No valid themes found in JSON';
          _isError = true;
        });
        return;
      }

      // Merge into existing custom themes.
      final repo = ref.read(customThemeRepositoryProvider);
      final existing = repo.getCustomThemes();
      existing.addAll(themes);
      repo.saveCustomThemes(existing);

      // Refresh the themes notifier.
      ref.invalidate(themesProvider);

      _importController.clear();
      setState(() {
        _statusMessage = 'Imported ${themes.length} theme(s) successfully!';
        _isError = false;
      });
    } on FormatException {
      setState(() {
        _statusMessage = 'Invalid JSON format';
        _isError = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Import error: $e';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export / Import'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Export section ---
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.upload_rounded,
                          color: colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Export Custom Themes',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Copy your custom themes as JSON to share with friends',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _exportToClipboard,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy to Clipboard'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Import section ---
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.download_rounded,
                          color: Colors.teal, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Import Themes',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste a JSON theme pack below to import',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _importController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: '{ "MyTheme": { "en": ["word1", ...] } }',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withAlpha(60),
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _importFromText,
                      icon: const Icon(Icons.download_done_rounded, size: 18),
                      label: const Text('Import'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Status message ---
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: (_isError ? Colors.red : Colors.green).withAlpha(20),
                border: Border.all(
                  color: (_isError ? Colors.red : Colors.green).withAlpha(60),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 20,
                    color:
                        _isError ? Colors.red.shade400 : Colors.green.shade400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isError
                            ? Colors.red.shade400
                            : Colors.green.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
