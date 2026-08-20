import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/streaks.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/lan_session_state.dart';
import 'package:impostor/features/lan_lobby/models/connected_device.dart';
import 'distributed_reveal_screen.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  StreamSubscription? _assignmentSub;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenForGame());
  }

  void _listenForGame() {
    final notifier = ref.read(lanSessionProvider.notifier);
    _assignmentSub = notifier.assignmentStream.listen((payload) {
      if (_navigating || !mounted) return;
      _navigating = true;
      Navigator.of(context).push(createSlideRoute(
        DistributedRevealScreen(assignmentPayload: payload),
      )).then((_) {
        // Reset once we're back on this screen so the next round's
        // assignment (a rematch) can trigger navigation again.
        if (mounted) _navigating = false;
      });
    });
  }

  @override
  void dispose() {
    _assignmentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LanSessionState>(lanSessionProvider, (previous, next) {
      final justStarted =
          next.phase == LanPhase.inGame && previous?.phase != LanPhase.inGame;
      final neverPicked = next.myDevice?.selectedPlayerName == null;
      if (justStarted && neverPicked) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Round Started Without You'),
            content: const Text(
              "You didn't pick a player before the host started. "
              "You'll be included next round.",
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    final session = ref.watch(lanSessionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Compute streaks from local history for streak preview
    final games = ref.read(gameHistoryRepositoryProvider).getGames();
    final streaks = computePlayerStreaks(games);

    final selectedName = session.myDevice?.selectedPlayerName;
    final connectedCount = session.devices
        .where((d) => d.connectionState == DeviceConnectionState.connected)
        .length;

    if (session.phase == LanPhase.idle) {
      return Scaffold(
        appBar: AppBar(title: const Text('Waiting Room')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                session.error ?? 'Disconnected from lobby',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(lanSessionProvider.notifier).endSession();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Waiting Room'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.devices_rounded, size: 16),
                label: Text('$connectedCount'),
                backgroundColor: colorScheme.primaryContainer,
                labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Status banner
            Card(
              color: colorScheme.secondaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Waiting for host to start the game…',
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Identity picker
            Text(
              'Who are you playing as?',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (session.players.isEmpty)
              Text(
                'Waiting for player list…',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              ...session.players.map((name) {
                final streak = streaks[name];
                final isSelected = selectedName == name;
                final takenByOther = session.devices.any((d) =>
                    d.selectedPlayerName == name &&
                    d.deviceId != session.myDeviceId);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: takenByOther
                        ? null
                        : () => ref
                            .read(lanSessionProvider.notifier)
                            .selectPlayerIdentity(name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest.withAlpha(60),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Opacity(
                        opacity: takenByOther ? 0.45 : 1,
                        child: Row(
                          children: [
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: colorScheme.primary, size: 22)
                            else
                              Icon(Icons.radio_button_unchecked_rounded,
                                  color: colorScheme.onSurfaceVariant, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  if (streak != null && streak.current >= 2)
                                    Text(
                                      '🔥 ${streak.current} win streak · best ${streak.best}',
                                      style: TextStyle(
                                        color: Colors.orange.shade400,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (takenByOther)
                              Text(
                                'taken',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

            if (selectedName != null) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: colorScheme.tertiaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded,
                          color: colorScheme.onTertiaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You are playing as $selectedName',
                          style: TextStyle(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Connected devices
            const SizedBox(height: 24),
            Text(
              'Devices in lobby',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...session.devices.map((d) {
              final (icon, color) = switch (d.connectionState) {
                DeviceConnectionState.connected =>
                  (Icons.check_circle_rounded, Colors.green),
                DeviceConnectionState.stale =>
                  (Icons.hourglass_top_rounded, Colors.orange),
                _ =>
                  (Icons.pending_rounded, colorScheme.onSurfaceVariant),
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(d.isHost ? Icons.star_rounded : Icons.smartphone_rounded,
                        size: 18, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.displayName + (d.isHost ? ' (host)' : ''),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Icon(icon, size: 16, color: color),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
