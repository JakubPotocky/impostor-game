import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Shared route transition – slide from right
// ---------------------------------------------------------------------------

/// Creates a slide-from-right page route with a fade.
Route<T> createSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return SlideTransition(
        position: Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}

// ---------------------------------------------------------------------------
// Setup card wrapper (used by SettingsScreen, PreGameScreen, etc.)
// ---------------------------------------------------------------------------

/// A themed card used in setup / settings screens.
class SetupCard extends StatelessWidget {
  const SetupCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Circle +/- button for impostor count
// ---------------------------------------------------------------------------

class CircleButton extends StatelessWidget {
  const CircleButton({super.key, required this.icon, this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      color: onPressed != null
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest.withAlpha(80),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 24,
            color: onPressed != null
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface.withAlpha(60),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated start-game button with pulsing effect
// ---------------------------------------------------------------------------

class StartGameButton extends StatefulWidget {
  const StartGameButton({
    super.key,
    required this.canStart,
    required this.onPressed,
  });
  final bool canStart;
  final VoidCallback onPressed;

  @override
  State<StartGameButton> createState() => _StartGameButtonState();
}

class _StartGameButtonState extends State<StartGameButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulse = Tween(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.canStart) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StartGameButton old) {
    super.didUpdateWidget(old);
    if (widget.canStart && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.canStart && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: widget.canStart ? _pulse : const AlwaysStoppedAnimation(1.0),
      child: SizedBox(
        height: 60,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: widget.canStart ? widget.onPressed : null,
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: const Text('Start Game', style: TextStyle(fontSize: 18)),
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staggered fade-in animation for list items
// ---------------------------------------------------------------------------

class StaggeredFadeIn extends StatefulWidget {
  const StaggeredFadeIn({super.key, required this.delay, required this.child});

  /// Stagger index (0, 1, 2, …). Each adds ~100ms delay.
  final int delay;
  final Widget child;

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(
      Duration(milliseconds: widget.delay * 100),
      () {
        if (mounted) _ctrl.forward();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Returns a theme-specific icon for the given theme name.
IconData themeIcon(String name) {
  switch (name) {
    case 'Animals':
      return Icons.pets;
    case 'Food':
      return Icons.restaurant;
    case 'Countries':
      return Icons.public;
    case 'Sports':
      return Icons.sports_soccer;
    case 'Movies':
      return Icons.movie;
    case 'Professions':
      return Icons.work;
    case 'Objects':
      return Icons.category;
    default:
      return Icons.label;
  }
}
