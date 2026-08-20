import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/validators.dart';
import 'package:impostor/core/word_hint_service.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/lan_session_state.dart';
import 'package:impostor/features/lan_lobby/models/connected_device.dart';
import 'package:impostor/features/lan_lobby/screens/lan_ready_check_screen.dart';
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

    final hasThemes = ref.watch(gameSetupProvider.select(
      (s) => s.selectedThemes.where((name) => name != 'Team Pairs').isNotEmpty,
    ));

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
                  const _ThemesCard(),
                  const SizedBox(height: 16),
                  _GameSettingsCard(session: session),
                  const SizedBox(height: 16),
                  _BrowserJoinCard(session: session),
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
                    onPressed:
                        (_starting || !hasThemes) ? null : _startGame,
                    icon: _starting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      _starting
                          ? 'Starting…'
                          : hasThemes
                              ? 'Start Game'
                              : 'Pick a theme to start',
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

  void _showCannotStart(String message) {
    setState(() => _starting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startGame() {
    final themesState = ref.read(themesProvider).valueOrNull;
    if (themesState == null) {
      _showCannotStart('Themes are still loading — try again in a moment.');
      return;
    }

    setState(() => _starting = true);

    // Read from the live LAN roster, not the pre-lobby players provider —
    // players can be added/removed from this screen after hosting starts.
    final allPlayers = ref.read(lanSessionProvider).players;
    final setup = ref.read(gameSetupProvider);
    final lanNotifier = ref.read(lanSessionProvider.notifier);
    final enabledThemes =
        setup.selectedThemes.where((name) => name != 'Team Pairs').toList();
    if (enabledThemes.isEmpty) {
      _showCannotStart('Enable at least one theme to start.');
      return;
    }

    final random = Random();
    final hasJ999 = allPlayers.any((p) => p == 'j999');
    final players = hasJ999
        ? allPlayers.where((p) => p != 'j999').toList()
        : List<String>.from(allPlayers);
    if (players.length < 3) {
      _showCannotStart('Need at least 3 players to start.');
      return;
    }

    // Guard against a stale/invalid saved impostor count (e.g. carried over
    // from a bigger game) rather than hanging or crashing role assignment.
    final maxImpostors = players.length - 1;
    final impostorCount = setup.impostorCount.clamp(1, maxImpostors);

    final isBlankRound = hasJ999 || random.nextInt(12) == 0;
    final theme = enabledThemes[random.nextInt(enabledThemes.length)];
    final language = setup.language;
    final englishWords = themesState.getEnglishWords(theme);
    if (englishWords.isEmpty) {
      _showCannotStart('The selected theme has no words — pick another theme.');
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
        impostorCount: impostorCount,
        word: word,
        random: random,
      );
    }

    // Split by claimed identity: each connected device that picked a player
    // gets only that player's reveal; anyone unclaimed (including the
    // host's own role, since the host never "picks" one) comes back here
    // for the host to reveal locally. Works for zero guests up to everyone
    // being claimed.
    final hostBucket = lanNotifier.distributeAssignments(
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
      themeVisibilityMode: setup.themeVisibilityMode.index,
      impostorHintWord: impostorHintWord,
      reducedMotion: setup.reducedMotion,
    );
    lanNotifier.triggerStartGame();

    final hostAssignments = hostBucket
        .map((a) => RoleAssignment(
              playerName: a['playerName'] as String,
              isImpostor: a['isImpostor'] as bool,
              word: a['word'] as String?,
            ))
        .toList();

    if (!mounted) return;

    final timerSeconds = setup.timerEnabled ? setup.timerMinutes * 60 : 0;
    Widget checkPlayersScreen(BuildContext ctx) => LanReadyCheckScreen(
          assignments: allAssignments,
          word: word,
          timerSeconds: timerSeconds,
          isBlankRound: isBlankRound,
          reducedMotion: setup.reducedMotion,
          suddenDeathEnabled: setup.suddenDeathEnabled,
        );

    if (hostAssignments.isEmpty) {
      // Every player was claimed by a connected device — the host has
      // nothing left to reveal locally, so go straight to the readiness
      // check for the guests who are revealing on their own phones.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Everyone's revealing on their own phone — checking readiness."),
      ));
      Navigator.of(context).push(createSlideRoute(checkPlayersScreen(context)));
      return;
    }

    Navigator.of(context).push(createSlideRoute(
      RoleRevealScreen(
        assignments: hostAssignments,
        votingAssignments: allAssignments,
        word: word,
        themeName: theme,
        hintsEnabled: setup.hintsEnabled,
        themeVisibilityMode: setup.themeVisibilityMode,
        impostorHintWord: impostorHintWord,
        timerSeconds: timerSeconds,
        isBlankRound: isBlankRound,
        reducedMotion: setup.reducedMotion,
        suddenDeathEnabled: setup.suddenDeathEnabled,
        onComplete: checkPlayersScreen,
        completeButtonLabel: 'Check Players',
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

class _ThemesCard extends ConsumerWidget {
  const _ThemesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final setup = ref.watch(gameSetupProvider);
    final themesAsync = ref.watch(themesProvider);
    final selected =
        setup.selectedThemes.where((n) => n != 'Team Pairs').toSet();

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
              Icon(Icons.category_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Round Themes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Pick while you wait for players to join.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            themesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('Error loading themes: $e'),
              data: (themesState) {
                final names = themesState.themeNames
                    .where((n) => n != 'Team Pairs')
                    .toList();
                if (names.isEmpty) {
                  return const Text('No themes available');
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: names.map((name) {
                    final isOn = selected.contains(name);
                    return FilterChip(
                      avatar: Icon(themeIcon(name), size: 18),
                      label: Text(name),
                      selected: isOn,
                      onSelected: (_) => ref
                          .read(gameSetupProvider.notifier)
                          .toggleTheme(name),
                      selectedColor: colorScheme.primaryContainer,
                      checkmarkColor: colorScheme.onPrimaryContainer,
                      labelStyle: TextStyle(
                        fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            if (selected.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Enable at least one theme to start',
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GameSettingsCard extends ConsumerWidget {
  const _GameSettingsCard({required this.session});
  final LanSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final setup = ref.watch(gameSetupProvider);
    final notifier = ref.read(gameSetupProvider.notifier);
    final playerCount = session.players.length;
    final validImpostors =
        playerCount == 0 || setup.impostorCount < playerCount;

    TextStyle? sectionTitle() =>
        textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);

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
              Icon(Icons.tune_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Round Settings',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 16),

            // --- Language ---
            Text('Word Language', style: sectionTitle()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.languageLabels.entries.map((entry) {
                final isSelected = setup.language == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (_) => notifier.setLanguage(entry.key),
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // --- Impostor count ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Impostors', style: sectionTitle()),
                Row(
                  children: [
                    CircleButton(
                      icon: Icons.remove,
                      onPressed: setup.impostorCount > 1
                          ? () => notifier.setImpostorCount(setup.impostorCount - 1)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${setup.impostorCount}',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    CircleButton(
                      icon: Icons.add,
                      onPressed: playerCount > 0 &&
                              setup.impostorCount < playerCount - 1
                          ? () => notifier.setImpostorCount(setup.impostorCount + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            if (!validImpostors)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Must be fewer than total players',
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),

            // --- Discussion timer ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discussion Timer', style: sectionTitle()),
                Switch(
                  value: setup.timerEnabled,
                  onChanged: notifier.setTimerEnabled,
                ),
              ],
            ),
            if (setup.timerEnabled) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleButton(
                    icon: Icons.remove,
                    onPressed: setup.timerMinutes > 1
                        ? () => notifier.setTimerMinutes(setup.timerMinutes - 1)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${setup.timerMinutes} min',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  CircleButton(
                    icon: Icons.add,
                    onPressed: setup.timerMinutes < 5
                        ? () => notifier.setTimerMinutes(setup.timerMinutes + 1)
                        : null,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // --- Hints ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hints', style: sectionTitle()),
                      Text(
                        'Show a clue with the revealed word',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: setup.hintsEnabled,
                  onChanged: notifier.setHintsEnabled,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Theme visibility ---
            Text('Theme Visibility', style: sectionTitle()),
            const SizedBox(height: 4),
            Text(
              'Show theme while revealing words',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SegmentedButton<ThemeVisibilityMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeVisibilityMode.off,
                  label: Text('Off'),
                  icon: Icon(Icons.visibility_off_rounded),
                ),
                ButtonSegment(
                  value: ThemeVisibilityMode.innocentsOnly,
                  label: Text('Innocents only'),
                  icon: Icon(Icons.shield_rounded),
                ),
                ButtonSegment(
                  value: ThemeVisibilityMode.everyone,
                  label: Text('Everyone'),
                  icon: Icon(Icons.visibility_rounded),
                ),
              ],
              selected: {setup.themeVisibilityMode},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                notifier.setThemeVisibilityMode(set.first);
              },
            ),
            const SizedBox(height: 20),

            // --- Sudden Death ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sudden Death', style: sectionTitle()),
                      Text(
                        'One wrong vote and innocents lose',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: setup.suddenDeathEnabled,
                  onChanged: notifier.setSuddenDeathEnabled,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserJoinCard extends StatelessWidget {
  const _BrowserJoinCard({required this.session});
  final LanSessionState session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final urls = session.browserJoinUrls;

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
              Icon(Icons.qr_code_2_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Join from a Phone Browser',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 8),
            if (urls.isEmpty)
              Text(
                'Resolving network address…',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else ...[
              Text(
                'No app needed — scan the code or open this link on the '
                'same Wi-Fi to join and pick a player.',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: urls.first,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        urls.first,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Copy link',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: urls.first));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                  ),
                ],
              ),
              if (urls.length > 1) ...[
                const SizedBox(height: 10),
                Text(
                  'On a different network interface? Try: '
                  '${urls.skip(1).join(', ')}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
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

class _PlayerListCard extends ConsumerStatefulWidget {
  const _PlayerListCard({required this.session});
  final LanSessionState session;

  @override
  ConsumerState<_PlayerListCard> createState() => _PlayerListCardState();
}

class _PlayerListCardState extends ConsumerState<_PlayerListCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addPlayer() {
    final error = Validators.validatePlayerName(
      _controller.text,
      maxLength: AppConstants.maxPlayerNameLength,
    );
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final name = Validators.makeUnique(
      _controller.text.trim(),
      widget.session.players,
    );
    ref
        .read(lanSessionProvider.notifier)
        .updatePlayers([...widget.session.players, name]);
    _controller.clear();
  }

  void _removePlayer(String name) {
    final remaining = widget.session.players.length - 1;
    if (!Validators.hasEnoughPlayers(remaining,
        minimum: AppConstants.minPlayers)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Need at least ${AppConstants.minPlayers} players.'),
      ));
      return;
    }
    ref.read(lanSessionProvider.notifier).updatePlayers(
        widget.session.players.where((p) => p != name).toList());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final players = widget.session.players;
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
                'Players (${players.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'You can add or remove players between rounds.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: players
                  .map((name) => InputChip(
                        label: Text(name),
                        onDeleted: () => _removePlayer(name),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        backgroundColor: colorScheme.secondaryContainer,
                        labelStyle:
                            TextStyle(color: colorScheme.onSecondaryContainer),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: AppConstants.maxPlayerNameLength,
                    decoration: const InputDecoration(
                      hintText: 'Add player',
                      counterText: '',
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addPlayer(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.person_add_alt_1),
                  tooltip: 'Add player',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
