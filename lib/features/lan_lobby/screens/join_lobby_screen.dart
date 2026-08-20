import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/services/mdns_service.dart';
import 'waiting_room_screen.dart';

class JoinLobbyScreen extends ConsumerStatefulWidget {
  const JoinLobbyScreen({super.key});

  @override
  ConsumerState<JoinLobbyScreen> createState() => _JoinLobbyScreenState();
}

class _JoinLobbyScreenState extends ConsumerState<JoinLobbyScreen> {
  final List<DiscoveredLobby> _lobbies = [];
  bool _browsing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startBrowsing();
  }

  void _startBrowsing() {
    setState(() {
      _browsing = true;
      _error = null;
    });
    ref.read(lanSessionProvider.notifier).browseLobbies().listen(
      (lobby) {
        if (!mounted) return;
        setState(() {
          final exists = _lobbies.any((l) => l.sessionId == lobby.sessionId);
          if (!exists) _lobbies.add(lobby);
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Discovery failed. Make sure Wi-Fi is enabled.';
          _browsing = false;
        });
      },
    );
  }

  @override
  void dispose() {
    ref.read(lanSessionProvider.notifier).stopBrowsing();
    super.dispose();
  }

  Future<void> _join(DiscoveredLobby lobby) async {
    await ref.read(lanSessionProvider.notifier).joinLobby(lobby);
    if (!mounted) return;
    // Watch for error or successful join in WaitingRoomScreen.
    Navigator.of(context).push(createSlideRoute(const WaitingRoomScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _lobbies.clear());
              _startBrowsing();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_browsing)
            LinearProgressIndicator(
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _lobbies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_find_rounded,
                            size: 64,
                            color: colorScheme.primary.withAlpha(80)),
                        const SizedBox(height: 16),
                        Text(
                          'Scanning for lobbies…',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(150),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make sure you are on the same Wi-Fi as the host.',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _lobbies.length,
                    itemBuilder: (context, i) {
                      final lobby = _lobbies[i];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.meeting_room_rounded,
                              color: colorScheme.primary),
                          title: Text(
                            lobby.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${lobby.mode.toUpperCase()} · v${lobby.appVersion}'
                            '${lobby.requiresPin ? ' · PIN required' : ''}',
                          ),
                          trailing: FilledButton(
                            onPressed: () => _join(lobby),
                            child: const Text('Join'),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
