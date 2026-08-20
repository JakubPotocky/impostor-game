import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/lan_session_state.dart';
// DeviceRevealProgress used by _RevealProgressBar

class DistributedRevealScreen extends ConsumerStatefulWidget {
  const DistributedRevealScreen({super.key, required this.assignmentPayload});
  final Map<String, dynamic> assignmentPayload;

  @override
  ConsumerState<DistributedRevealScreen> createState() =>
      _DistributedRevealScreenState();
}

class _DistributedRevealScreenState
    extends ConsumerState<DistributedRevealScreen> {
  late final List<RoleAssignment> _assignments;
  late final String _word;
  late final bool _hintsEnabled;
  late final String? _impostorHintWord;
  late final bool _reducedMotion;
  int _currentIndex = 0;
  bool _revealed = false;
  bool _done = false;
  StreamSubscription? _allRevealsSub;

  @override
  void initState() {
    super.initState();
    _parsePayload();
    _listenForAllComplete();
  }

  void _parsePayload() {
    final raw = (widget.assignmentPayload['assignments'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    _assignments = raw
        .map((a) => RoleAssignment(
              playerName: a['playerName'] as String? ?? '',
              isImpostor: a['isImpostor'] as bool? ?? false,
              word: a['word'] as String?,
            ))
        .toList();
    _word = widget.assignmentPayload['word'] as String? ?? '';
    _hintsEnabled = widget.assignmentPayload['hintsEnabled'] as bool? ?? false;
    _impostorHintWord = widget.assignmentPayload['impostorHintWord'] as String?;
    _reducedMotion =
        widget.assignmentPayload['reducedMotion'] as bool? ?? false;
  }

  void _listenForAllComplete() {
    _allRevealsSub =
        ref.read(lanSessionProvider.notifier).allRevealsStream.listen((_) {
      if (!mounted || !_done) return;
      // When host signals all reveals complete, pop back to waiting room.
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _allRevealsSub?.cancel();
    super.dispose();
  }

  void _onReveal() => setState(() => _revealed = true);

  void _onNext() {
    final next = _currentIndex + 1;
    final notifier = ref.read(lanSessionProvider.notifier);
    if (next >= _assignments.length) {
      setState(() {
        _currentIndex = next - 1;
        _revealed = false;
        _done = true;
      });
      notifier.reportRevealProgress(_assignments.length, _assignments.length);
    } else {
      setState(() {
        _currentIndex = next;
        _revealed = false;
      });
      notifier.reportRevealProgress(next, _assignments.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_assignments.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Role Reveal')),
        body: const Center(child: Text('No players assigned to this device.')),
      );
    }

    if (_done) {
      return Scaffold(
        appBar: AppBar(title: const Text('Role Reveal')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_all_rounded,
                  size: 72, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'All your reveals done!',
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for other devices to finish…',
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant, fontSize: 15),
              ),
              const SizedBox(height: 20),
              _RevealProgressBar(
                progress: ref.watch(lanSessionProvider).revealProgress,
              ),
            ],
          ),
        ),
      );
    }

    final assignment = _assignments[_currentIndex];
    final isImpostor = assignment.isImpostor;
    final word = assignment.word ?? _word;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Player ${_currentIndex + 1} of ${_assignments.length}',
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _revealed
                      ? _RevealCard(
                          key: ValueKey('revealed_$_currentIndex'),
                          playerName: assignment.playerName,
                          isImpostor: isImpostor,
                          word: word,
                          hintsEnabled: _hintsEnabled,
                          impostorHintWord: _impostorHintWord,
                          reducedMotion: _reducedMotion,
                        )
                      : _HiddenCard(
                          key: ValueKey('hidden_$_currentIndex'),
                          playerName: assignment.playerName,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_revealed)
              FilledButton.icon(
                onPressed: _onReveal,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Reveal My Role'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _onNext,
                icon: Icon(
                  _currentIndex + 1 >= _assignments.length
                      ? Icons.done_all_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _currentIndex + 1 >= _assignments.length
                      ? 'Finish'
                      : 'Pass to Next Player',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Cards ────────────────────────────────────────────────────────────────────

class _HiddenCard extends StatelessWidget {
  const _HiddenCard({super.key, required this.playerName});
  final String playerName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              playerName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Hand the phone to this player,\nthen tap Reveal.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    super.key,
    required this.playerName,
    required this.isImpostor,
    required this.word,
    required this.hintsEnabled,
    required this.impostorHintWord,
    required this.reducedMotion,
  });

  final String playerName;
  final bool isImpostor;
  final String word;
  final bool hintsEnabled;
  final String? impostorHintWord;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isImp = isImpostor;

    return Card(
      elevation: 4,
      color: isImp ? colorScheme.errorContainer : colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isImp ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              size: 64,
              color: isImp
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 16),
            Text(
              isImp ? 'You are the IMPOSTOR' : word,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isImp
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isImp
                  ? 'Blend in. Don\'t get caught!'
                  : 'This is the secret word.',
              style: TextStyle(
                color: isImp
                    ? colorScheme.onErrorContainer.withAlpha(180)
                    : colorScheme.onPrimaryContainer.withAlpha(180),
              ),
              textAlign: TextAlign.center,
            ),
            if (isImp &&
                hintsEnabled &&
                (impostorHintWord ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Hint word: ${impostorHintWord!.trim()}',
                style: TextStyle(
                  color: colorScheme.onErrorContainer.withAlpha(180),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Progress bar ─────────────────────────────────────────────────────────────

class _RevealProgressBar extends StatelessWidget {
  const _RevealProgressBar({required this.progress});
  final Map<String, DeviceRevealProgress> progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (progress.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device progress',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...progress.entries.map((e) {
            final p = e.value;
            final completed = p.completed;
            final total = p.total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: total > 0 ? completed / total : 0,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed/$total',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
