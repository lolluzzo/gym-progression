import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gym_progression/models/achievement.dart';

/// Celebratory dialog with a confetti burst, for workouts, PRs and
/// unlocked achievements.
Future<void> showCelebration(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  List<Achievement> unlocked = const [],
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, _, __) => _CelebrationDialog(
      icon: icon,
      title: title,
      message: message,
      unlocked: unlocked,
    ),
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
      );
    },
  );
}

class _CelebrationDialog extends StatefulWidget {
  const _CelebrationDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.unlocked,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Achievement> unlocked;

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  final List<_Particle> _particles = _Particle.burst(80);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_confetti.isAnimating) {
      _confetti.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PopIn(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [scheme.primary, scheme.tertiary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            size: 48,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.message,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.unlocked.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          widget.unlocked.length == 1
                              ? 'Achievement unlocked'
                              : 'Achievements unlocked',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final achievement in widget.unlocked)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  achievement.icon,
                                  color: scheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        achievement.title,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          color: scheme.onTertiaryContainer,
                                        ),
                                      ),
                                      Text(
                                        achievement.description,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: scheme.onTertiaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Let's go!"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confetti.value,
                  colors: [
                    scheme.primary,
                    scheme.tertiary,
                    const Color(0xFFFFC107),
                    const Color(0xFF3987E5),
                    const Color(0xFFE87BA4),
                    const Color(0xFF1BAF7A),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.colorIndex,
  });

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final int colorIndex;

  /// Particles shot upwards in a fan from one point.
  static List<_Particle> burst(int count) {
    final random = math.Random();
    return List.generate(count, (index) {
      return _Particle(
        angle: -math.pi / 2 + (random.nextDouble() - 0.5) * 2.2,
        speed: 450 + random.nextDouble() * 550,
        size: 6 + random.nextDouble() * 6,
        spin: (random.nextDouble() - 0.5) * 20,
        colorIndex: index,
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.colors,
  });

  final List<_Particle> particles;
  final double progress;
  final List<Color> colors;

  static const double _gravity = 1100;
  static const double _durationSeconds = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) {
      return;
    }

    final time = progress * _durationSeconds;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final opacity = 1 - math.pow(progress, 3).toDouble();
    final paint = Paint();

    for (final particle in particles) {
      final position = origin +
          Offset(
            math.cos(particle.angle) * particle.speed * time,
            math.sin(particle.angle) * particle.speed * time +
                0.5 * _gravity * time * time,
          );

      paint.color = colors[particle.colorIndex % colors.length]
          .withValues(alpha: opacity);

      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(particle.spin * time)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size * 0.5,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
