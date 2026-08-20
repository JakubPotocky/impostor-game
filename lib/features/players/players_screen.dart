import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/streaks.dart';
import 'package:impostor/core/validators.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/features/players/players_notifier.dart';
import 'package:impostor/features/pre_game/pre_game_screen.dart';
import 'package:impostor/features/team_mode/team_mode_screen.dart';

enum GameMode {
  normal,
  team,
}

/// Screen for managing players — add, edit, delete, reorder.
class PlayersScreen extends ConsumerStatefulWidget {
  const PlayersScreen({super.key, this.mode = GameMode.normal});

  final GameMode mode;

  @override
  ConsumerState<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends ConsumerState<PlayersScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _addPlayer() {
    ref.read(playersProvider.notifier).addPlayer(_nameController.text);
    _nameController.clear();
    _nameFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final playersState = ref.watch(playersProvider);
    final players = playersState.players;
    final games = ref.read(gameHistoryRepositoryProvider).getGames();
    final streaks = computePlayerStreaks(games);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${players.length}',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Add player input ---
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.surfaceContainerHighest.withAlpha(80),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    maxLength: AppConstants.maxPlayerNameLength,
                    decoration: InputDecoration(
                      hintText: 'Enter name or leave empty',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withAlpha(100),
                      ),
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addPlayer(),
                  ),
                ),
                const SizedBox(width: 8),
                _AnimatedAddButton(onPressed: _addPlayer),
              ],
            ),
          ),

          // --- Continue button (above the player list) ---
          Builder(
            builder: (context) {
              final count = ref.watch(playersProvider).count;
              final hasEnough = Validators.hasEnoughPlayers(count,
                  minimum: AppConstants.minPlayers);
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: hasEnough
                        ? () {
                            Navigator.of(context).push(
                              createSlideRoute(
                                widget.mode == GameMode.team
                                    ? const TeamModeScreen()
                                    : const PreGameScreen(),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      hasEnough
                          ? 'Continue'
                          : 'Need ${AppConstants.minPlayers - count} more',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // --- Player list ---
          Expanded(
            child: players.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1,
                            size: 64, color: colorScheme.primary.withAlpha(80)),
                        const SizedBox(height: 16),
                        Text(
                          'Add at least 3 players to start',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(150),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: players.length,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final t = Curves.easeInOut.transform(animation.value);
                          final elevation = 1.0 + t * 8.0;
                          return Material(
                            elevation: elevation,
                            borderRadius: BorderRadius.circular(12),
                            color: colorScheme.surfaceContainerHigh,
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(playersProvider.notifier)
                          .reorderPlayer(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      return _PlayerTile(
                        key: ValueKey('player_${index}_${players[index]}'),
                        index: index,
                        name: players[index],
                        onEdit: (newName) {
                          ref
                              .read(playersProvider.notifier)
                              .editPlayer(index, newName);
                        },
                        onDelete: () {
                          ref
                              .read(playersProvider.notifier)
                              .removePlayer(index);
                        },
                        streak: streaks[players[index]]?.current ?? 0,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated add button
// ---------------------------------------------------------------------------
class _AnimatedAddButton extends StatefulWidget {
  const _AnimatedAddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: IconButton.filled(
        onPressed: _handleTap,
        icon: const Icon(Icons.person_add_alt_1),
        tooltip: 'Add player',
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player tile
// ---------------------------------------------------------------------------
class _PlayerTile extends StatefulWidget {
  const _PlayerTile({
    required super.key,
    required this.index,
    required this.name,
    required this.streak,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final String name;
  final int streak;
  final ValueChanged<String> onEdit;
  final VoidCallback onDelete;

  @override
  State<_PlayerTile> createState() => _PlayerTileState();
}

class _PlayerTileState extends State<_PlayerTile>
    with SingleTickerProviderStateMixin {
  bool _editing = false;
  late final TextEditingController _controller;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_PlayerTile old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name && !_editing) {
      _controller.text = widget.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _submitEdit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onEdit(text);
    } else {
      _controller.text = widget.name;
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeIn,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 8, right: 4),
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '${widget.index + 1}',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: _editing
              ? TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: AppConstants.maxPlayerNameLength,
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submitEdit(),
                )
              : Text(
                  widget.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
          subtitle: widget.streak >= 2
              ? Text(
                  '🔥 ${widget.streak} win streak',
                  style: TextStyle(
                    color: Colors.orange.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_editing)
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 20, color: colorScheme.primary),
                  onPressed: () => setState(() => _editing = true),
                  tooltip: 'Edit',
                ),
              if (_editing)
                IconButton(
                  icon: Icon(Icons.check_circle,
                      size: 20, color: colorScheme.primary),
                  onPressed: _submitEdit,
                  tooltip: 'Confirm',
                ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: colorScheme.error),
                onPressed: widget.onDelete,
                tooltip: 'Delete',
              ),
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_handle,
                      color: colorScheme.onSurface.withAlpha(100)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
