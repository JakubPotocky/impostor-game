import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/word_hint_service.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/lan_session_state.dart';
import 'package:impostor/features/lan_lobby/models/connected_device.dart';
import 'package:impostor/features/players/players_notifier.dart';
import 'package:impostor/features/players/players_screen.dart';
import 'package:impostor/features/pre_game/pre_game_screen.dart';
import 'package:impostor/features/role_reveal/role_reveal_screen.dart';
import 'package:impostor/features/themes/themes_notifier.dart';

class HostLobbyScreen extends ConsumerStatefulWidget {
  const HostLobbyScreen({super.key, required this.mode});
  final GameMode mode;

  @override
  ConsumerState<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends ConsumerState<HostLobbyScreen> {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _createLobby());
  }

  Future<void> _createLobby() async {
    final players = ref.read(playersProvider).players;
    await ref.read(lanSessionProvider.notifier).createLobby(
          mode: widget.mode.name,
          players: players,
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(lanSessionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final connectedCount = session.devices
        .where((d) => d.connectionState == DeviceConnectionState.connected)
        .length;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(lanSessionProvider.notifier).endSession();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Host Lobby'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.wifi_rounded, size: 16),
                label: Text('$connectedCount connected'),
                backgroundColor: colorScheme.primaryContainer,
                labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
        body: session.phase == LanPhase.idle
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _LobbyInfoCard(session: session),
                  const SizedBox(height: 16),
                  _DeviceListCard(session: session),
                  const SizedBox(height: 16),
                  _PlayerListCard(session: session),
                  if (session.error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          session.error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: session.phase == LanPhase.inLobby
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _starting ? null : _startGame,
                    icon: _starting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      _starting ? 'Starting…' : 'Start Game',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  void _startGame() {
    final themesState = ref.read(themesProvider).valueOrNull;
    if (themesState == null) return;

    setState(() => _starting = true);

    final allPlayers = ref.read(playersProvider).players;
    final setup = ref.read(gameSetupProvider);
    final lanNotifier = ref.read(lanSessionProvider.notifier);
    final enabledThemes =
        setup.selectedThemes.where((name) => name != 'Team Pairs').toList();
    if (enabledThemes.isEmpty) {
      setState(() => _starting = false);
      return;
    }

    final random = Random();
    final hasJ999 = allPlayers.any((p) => p == 'j999');
    final players = hasJ999
        ? allPlayers.where((p) => p != 'j999').toList()
        : List<String>.from(allPlayers);
    if (players.length < 3) {
      setState(() => _starting = false);
      return;
    }

    final isBlankRound = hasJ999 || random.nextInt(12) == 0;
    final theme = enabledThemes[random.nextInt(enabledThemes.length)];
    final language = setup.language;
    final englishWords = themesState.getEnglishWords(theme);
    if (englishWords.isEmpty) {
      setState(() => _starting = false);
      return;
    }

    final wordPicker = ref.read(wordPickerServiceProvider);
    final wordIndex = wordPicker.pickWordIndex(
      theme: theme,
      wordCount: englishWords.length,
      random: random,
    );
    final translatedWords = themesState.getWords(theme, language);
    final word = wordIndex < translatedWords.length
        ? translatedWords[wordIndex]
        : englishWords[wordIndex];
    final impostorHintWord = pickImpostorHintWord(
      themeWords: translatedWords.isNotEmpty ? translatedWords : englishWords,
      secretWord: word,
      random: random,
    );

    List<RoleAssignment> allAssignments;
    if (isBlankRound) {
      allAssignments = players
          .map((name) => RoleAssignment(playerName: name, isImpostor: true))
          .toList();
    } else {
      const roleService = RoleAssignmentService();
      allAssignments = roleService.assignRoles(
        players: players,
        impostorCount: setup.impostorCount,
        word: word,
        random: random,
      );
    }

    // Partition and send to clients.
    lanNotifier.distributeAssignments(
      allAssignments: allAssignments
          .map((a) => {
                'playerName': a.playerName,
                'isImpostor': a.isImpostor,
                'word': a.word,
              })
          .toList(),
      word: word,
      themeName: theme,
      hintsEnabled: setup.hintsEnabled,
      impostorHintWord: impostorHintWord,
      reducedMotion: setup.reducedMotion,
    );
    lanNotifier.triggerStartGame();

    // Determine host's own subset (device index 0 = host, sorted by joinOrder).
    final connectedDevices = ref
        .read(lanSessionProvider)
        .devices
        .where((d) => d.connectionState == DeviceConnectionState.connected)
        .toList()
      ..sort((a, b) => a.joinOrder.compareTo(b.joinOrder));
    final deviceCount = connectedDevices.length;
    final hostAssignments = <RoleAssignment>[];
    for (var i = 0; i < allAssignments.length; i++) {
      if (i % deviceCount == 0) {
        hostAssignments.add(allAssignments[i]);
      }
    }

    if (!mounted) return;
    Navigator.of(context).push(createSlideRoute(
      RoleRevealScreen(
        assignments: hostAssignments,
        word: word,
        themeName: theme,
        hintsEnabled: setup.hintsEnabled,
        impostorHintWord: impostorHintWord,
        timerSeconds: setup.timerEnabled ? setup.timerMinutes * 60 : 0,
        isBlankRound: isBlankRound,
        reducedMotion: setup.reducedMotion,
        suddenDeathEnabled: setup.suddenDeathEnabled,
      ),
    ));
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _LobbyInfoCard extends StatelessWidget {
  const _LobbyInfoCard({required this.session});
  final LanSessionState session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final s = session.session;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.meeting_room_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Lobby Info',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 12),
            if (s != null) ...[
              _InfoRow(label: 'Name', value: s.lobbyName),
              const SizedBox(height: 4),
              _InfoRow(label: 'Mode', value: s.mode),
              const SizedBox(height: 4),
            ],
            Text(
              'Friends on the same Wi-Fi will see this lobby automatically.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value),
      ],
    );
  }
}

class _DeviceListCard extends StatelessWidget {
  const _DeviceListCard({required this.session});
  final LanSessionState session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.devices_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Connected Devices',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 12),
            ...session.devices.map((d) => _DeviceTile(device: d)),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});
  final ConnectedDevice device;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (device.connectionState) {
      DeviceConnectionState.connected => (
          Icons.check_circle_rounded,
          Colors.green
        ),
      DeviceConnectionState.stale => (
          Icons.hourglass_top_rounded,
          Colors.orange
        ),
      DeviceConnectionState.connecting => (
          Icons.pending_rounded,
          colorScheme.primary
        ),
      DeviceConnectionState.disconnected => (
          Icons.cancel_rounded,
          colorScheme.error
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(device.isHost ? Icons.star_rounded : Icons.smartphone_rounded,
              size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName + (device.isHost ? ' (you)' : ''),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (device.selectedPlayerName != null)
                  Text(
                    'Playing as: ${device.selectedPlayerName}',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Icon(icon, size: 18, color: color),
        ],
      ),
    );
  }
}

class _PlayerListCard extends StatelessWidget {
  const _PlayerListCard({required this.session});
  final LanSessionState session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.people_alt_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Players (${session.players.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: session.players
                  .map((name) => Chip(
                        label: Text(name),
                        backgroundColor: colorScheme.secondaryContainer,
                        labelStyle:
                            TextStyle(color: colorScheme.onSecondaryContainer),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
