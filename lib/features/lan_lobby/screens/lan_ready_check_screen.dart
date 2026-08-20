import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/lan_session_state.dart';
import 'package:impostor/features/lan_lobby/models/connected_device.dart';
import 'package:impostor/features/players/players_screen.dart';
import 'package:impostor/features/voting/voting_screen.dart';
import 'host_lobby_screen.dart';

enum _ReadyStatus { ready, revealing, noPlayer }

/// Shown after the host finishes their own reveals in a LAN game, before
/// voting starts. Lets the host see whether connected guests have looked
/// at their role yet — informational only, never blocks — and offers a
/// way back to the lobby (themes, roster, new joiners) instead of forcing
/// straight into voting.
class LanReadyCheckScreen extends ConsumerWidget {
  const LanReadyCheckScreen({
    super.key,
    required this.assignments,
    required this.word,
    required this.timerSeconds,
    required this.isBlankRound,
    required this.reducedMotion,
    required this.suddenDeathEnabled,
  });

  final List<RoleAssignment> assignments;
  final String word;
  final int timerSeconds;
  final bool isBlankRound;
  final bool reducedMotion;
  final bool suddenDeathEnabled;

  GameMode _currentMode(LanSessionState session) {
    final modeName = session.session?.mode;
    return GameMode.values
        .firstWhere((m) => m.name == modeName, orElse: () => GameMode.normal);
  }

  void _continueToVoting(BuildContext context) {
    Navigator.of(context).pushReplacement(createSlideRoute(
      VotingScreen(
        assignments: assignments,
        word: word,
        timerSeconds: timerSeconds,
        isBlankRound: isBlankRound,
        reducedMotion: reducedMotion,
        suddenDeathEnabled: suddenDeathEnabled,
      ),
    ));
  }

  void _backToLobby(BuildContext context, WidgetRef ref) {
    final mode = _currentMode(ref.read(lanSessionProvider));
    ref.read(lanSessionProvider.notifier).returnToLobby();
    Navigator.of(context).pushAndRemoveUntil(
      createSlideRoute(HostLobbyScreen(mode: mode)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(lanSessionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final guests = session.devices
        .where((d) =>
            !d.isHost && d.connectionState == DeviceConnectionState.connected)
        .toList();

    final statuses = <ConnectedDevice, _ReadyStatus>{
      for (final d in guests)
        d: d.selectedPlayerName == null
            ? _ReadyStatus.noPlayer
            : (session.revealProgress[d.deviceId] == null ||
                    session.revealProgress[d.deviceId]!.completed >=
                        session.revealProgress[d.deviceId]!.total)
                ? _ReadyStatus.ready
                : _ReadyStatus.revealing,
    };
    final notReadyCount =
        statuses.values.where((s) => s == _ReadyStatus.revealing).length;
    final allReady = notReadyCount == 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Check Players'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Card(
              elevation: 0,
              color: allReady
                  ? Colors.green.withAlpha(25)
                  : Colors.amber.withAlpha(25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: allReady ? Colors.green : Colors.amber.shade700,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      allReady
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded,
                      color: allReady ? Colors.green : Colors.amber.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        allReady
                            ? 'Everyone has seen their role.'
                            : '$notReadyCount player(s) still revealing their role.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              allReady ? Colors.green.shade700 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (guests.isEmpty)
              Text(
                'No other devices connected this round — you revealed everyone.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else ...[
              Text(
                'Connected players',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...guests.map((d) {
                final status = statuses[d]!;
                final (icon, color, label) = switch (status) {
                  _ReadyStatus.ready => (
                      Icons.check_circle_rounded,
                      Colors.green,
                      'Ready',
                    ),
                  _ReadyStatus.revealing => (
                      Icons.hourglass_top_rounded,
                      Colors.amber.shade700,
                      'Revealing…',
                    ),
                  _ReadyStatus.noPlayer => (
                      Icons.person_off_outlined,
                      colorScheme.onSurfaceVariant,
                      'No player picked',
                    ),
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.smartphone_rounded,
                          size: 18, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.selectedPlayerName ?? d.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(label,
                          style: TextStyle(fontSize: 12, color: color)),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _continueToVoting(context),
                icon: const Icon(Icons.how_to_vote_rounded),
                label: Text(
                  allReady ? 'Continue to Voting' : 'Continue Anyway',
                  style: const TextStyle(fontSize: 18),
                ),
                style: FilledButton.styleFrom(
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _backToLobby(context, ref),
                icon: const Icon(Icons.settings_backup_restore_rounded),
                label: const Text('Back to Lobby / Settings',
                    style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
