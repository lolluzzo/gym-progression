import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gym_progression/services/progress_stats.dart';

enum AchievementMetric { workouts, personalRecords, bestStreak, volumeKg }

class Achievement {
  const Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.metric,
    required this.target,
  });

  final String title;
  final String description;
  final IconData icon;
  final AchievementMetric metric;
  final double target;

  double valueFor(ProfileStats stats) {
    return switch (metric) {
      AchievementMetric.workouts => stats.totalCompleted.toDouble(),
      AchievementMetric.personalRecords => stats.personalRecords.toDouble(),
      AchievementMetric.bestStreak => stats.bestStreak.toDouble(),
      AchievementMetric.volumeKg => stats.totalVolumeKg,
    };
  }

  double progressFor(ProfileStats stats) {
    return math.min(1, valueFor(stats) / target);
  }

  bool isUnlockedBy(ProfileStats stats) => valueFor(stats) >= target;

  String progressLabel(ProfileStats stats) {
    final value = math.min(valueFor(stats), target);
    if (metric == AchievementMetric.volumeKg) {
      return '${formatVolume(value)} / ${formatVolume(target)}';
    }

    return '${value.toInt()} / ${target.toInt()}';
  }
}

const List<Achievement> achievements = [
  Achievement(
    title: 'First step',
    description: 'Complete your first workout',
    icon: Icons.flag_rounded,
    metric: AchievementMetric.workouts,
    target: 1,
  ),
  Achievement(
    title: 'Getting serious',
    description: 'Complete 10 workouts',
    icon: Icons.fitness_center_rounded,
    metric: AchievementMetric.workouts,
    target: 10,
  ),
  Achievement(
    title: 'Gym regular',
    description: 'Complete 50 workouts',
    icon: Icons.event_available_rounded,
    metric: AchievementMetric.workouts,
    target: 50,
  ),
  Achievement(
    title: 'Centurion',
    description: 'Complete 100 workouts',
    icon: Icons.military_tech_rounded,
    metric: AchievementMetric.workouts,
    target: 100,
  ),
  Achievement(
    title: 'Record breaker',
    description: 'Set your first personal record',
    icon: Icons.emoji_events_rounded,
    metric: AchievementMetric.personalRecords,
    target: 1,
  ),
  Achievement(
    title: 'PR machine',
    description: 'Set 10 personal records',
    icon: Icons.trending_up_rounded,
    metric: AchievementMetric.personalRecords,
    target: 10,
  ),
  Achievement(
    title: 'On a roll',
    description: 'Train 4 weeks in a row',
    icon: Icons.local_fire_department_rounded,
    metric: AchievementMetric.bestStreak,
    target: 4,
  ),
  Achievement(
    title: 'Unstoppable',
    description: 'Train 12 weeks in a row',
    icon: Icons.bolt_rounded,
    metric: AchievementMetric.bestStreak,
    target: 12,
  ),
  Achievement(
    title: '10 tonne club',
    description: 'Lift 10,000 kg in total',
    icon: Icons.scale_rounded,
    metric: AchievementMetric.volumeKg,
    target: 10000,
  ),
  Achievement(
    title: '100 tonne club',
    description: 'Lift 100,000 kg in total',
    icon: Icons.landscape_rounded,
    metric: AchievementMetric.volumeKg,
    target: 100000,
  ),
];

List<Achievement> newlyUnlocked(ProfileStats before, ProfileStats after) {
  return achievements
      .where((achievement) =>
          !achievement.isUnlockedBy(before) && achievement.isUnlockedBy(after))
      .toList();
}
