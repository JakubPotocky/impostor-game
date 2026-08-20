import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Confetti / Particle celebration overlay
// ---------------------------------------------------------------------------

/// A fullscreen confetti burst that plays once and auto-disposes.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.particleCount = 60,
    this.colors,
    this.duration = const Duration(milliseconds: 2500),
  });

  final int particleCount;
  final List<Color>? colors;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    final rng = Random();
    final colors = widget.colors ??
        [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
          Colors.pink,
        ];
    _particles = List.generate(widget.particleCount, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 200 + rng.nextDouble() * 400;
      return _Particle(
        dx: cos(angle) * speed,
        dy: sin(angle) * speed - 200, // bias upwards
        rotation: rng.nextDouble() * 2 * pi,
        rotationSpeed: (rng.nextDouble() - 0.5) * 10,
        size: 4 + rng.nextDouble() * 8,
        color: colors[rng.nextInt(colors.length)],
        shape: rng.nextInt(3), // 0=rect, 1=circle, 2=triangle
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _ctrl.value,
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.dx,
    required this.dy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.shape,
  });

  final double dx;
  final double dy;
  final double rotation;
  final double rotationSpeed;
  final double size;
  final Color color;
  final int shape;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.35;
    final gravity = 600.0;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final t = progress;
      final x = cx + p.dx * t;
      final y = cy + p.dy * t + 0.5 * gravity * t * t;
      final angle = p.rotation + p.rotationSpeed * t;

      if (x < -20 || x > size.width + 20 || y > size.height + 20) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final paint = Paint()
        ..color = p.color.withAlpha((opacity * 0.85 * 255).round());

      switch (p.shape) {
        case 0: // rectangle
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.5),
            paint,
          );
          break;
        case 1: // circle
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
          break;
        case 2: // triangle
          final path = Path()
            ..moveTo(0, -p.size * 0.4)
            ..lineTo(p.size * 0.35, p.size * 0.3)
            ..lineTo(-p.size * 0.35, p.size * 0.3)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

// ---------------------------------------------------------------------------
// Animated glow ring — used around role reveal icons
// ---------------------------------------------------------------------------

/// A pulsing, rotating glow ring.
class GlowRing extends StatefulWidget {
  const GlowRing({
    super.key,
    required this.color,
    this.size = 140,
    this.child,
  });

  final Color color;
  final double size;
  final Widget? child;

  @override
  State<GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<GlowRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final pulse = 1.0 + 0.08 * sin(_ctrl.value * 2 * pi);
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withAlpha(
                    ((0.2 + 0.15 * sin(_ctrl.value * 2 * pi)) * 255).round(),
                  ),
                  blurRadius: 30 + 15 * sin(_ctrl.value * 2 * pi),
                  spreadRadius: 5 + 5 * sin(_ctrl.value * 2 * pi),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _GlowRingPainter(
                color: widget.color,
                progress: _ctrl.value,
              ),
              child: Center(child: child),
            ),
          ),
        );
      },
    );
  }
}

class _GlowRingPainter extends CustomPainter {
  _GlowRingPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Rotating gradient arc
    final sweep = pi * 1.2;
    final startAngle = progress * 2 * pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: [
          color.withAlpha(0),
          color.withAlpha(153),
          color.withAlpha(0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);

    // Static faint ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withAlpha(38);
    canvas.drawCircle(center, radius, bgPaint);
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) => true;
}

// ---------------------------------------------------------------------------
// Shimmer text effect
// ---------------------------------------------------------------------------

/// Text with a sliding shimmer highlight.
class ShimmerText extends StatefulWidget {
  const ShimmerText({
    super.key,
    required this.text,
    this.style,
    this.shimmerColor,
  });

  final String text;
  final TextStyle? style;
  final Color? shimmerColor;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.style?.color ?? Colors.white;
    final shimmer = widget.shimmerColor ?? Colors.white;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final dx = -1.0 + 3.0 * _ctrl.value;
            return LinearGradient(
              begin: Alignment(dx - 0.3, 0),
              end: Alignment(dx + 0.3, 0),
              colors: [baseColor, shimmer, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style?.copyWith(color: Colors.white) ??
                const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dramatic entrance — scale + rotate + fade
// ---------------------------------------------------------------------------

/// A widget that dramatically scales in with a slight rotation.
class DramaticEntrance extends StatefulWidget {
  const DramaticEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.elasticOut,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  @override
  State<DramaticEntrance> createState() => _DramaticEntranceState();
}

class _DramaticEntranceState extends State<DramaticEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: widget.curve),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Screen shake effect
// ---------------------------------------------------------------------------

/// Wraps a child with a brief shake animation (for impostor reveals, kills).
class ShakeEffect extends StatefulWidget {
  const ShakeEffect({
    super.key,
    required this.child,
    required this.trigger,
    this.intensity = 8.0,
    this.duration = const Duration(milliseconds: 500),
  });

  final Widget child;

  /// Change this value to trigger a new shake.
  final int trigger;
  final double intensity;
  final Duration duration;

  @override
  State<ShakeEffect> createState() => _ShakeEffectState();
}

class _ShakeEffectState extends State<ShakeEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _lastTrigger = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _lastTrigger = widget.trigger;
  }

  @override
  void didUpdateWidget(covariant ShakeEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != _lastTrigger) {
      _lastTrigger = widget.trigger;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final decay = 1.0 - t; // diminishes over time
        final offset = sin(t * 6 * pi) * widget.intensity * decay;
        return Transform.translate(
          offset: Offset(offset, offset * 0.3),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
