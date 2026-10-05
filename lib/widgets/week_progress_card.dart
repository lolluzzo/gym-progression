import 'package:flutter/material.dart';

/// Home header: this week's workouts as a ring, plus the weekly streak.
class WeekProgressCard extends StatelessWidget {
  const WeekProgressCard({
    super.key,
    required this.completed,
    required this.planned,
    required this.streak,
  });

  final int completed;
  final int planned;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress =
        planned == 0 ? 0.0 : (completed / planned).clamp(0.0, 1.0);
    final isPerfectWeek = planned > 0 && completed >= planned;
    final remaining = planned - completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => SizedBox.square(
              dimension: 84,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    color: scheme.primary,
                    backgroundColor:
                        scheme.onPrimaryContainer.withValues(alpha: 0.12),
                  ),
                  Center(
                    child: isPerfectWeek
                        ? Icon(
                            Icons.check_rounded,
                            size: 40,
                            color: scheme.primary,
                          )
                        : Text(
                            '$completed/$planned',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPerfectWeek ? 'Perfect week!' : 'This week',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPerfectWeek
                      ? 'Every workout done. Enjoy the rest.'
                      : '$remaining ${remaining == 1 ? 'workout' : 'workouts'} to go',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                StreakChip(streak: streak),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isActive = streak > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: isActive ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isActive
                  ? '$streak-week streak'
                  : 'Finish a workout to start a streak',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
