import 'dart:math' as math;

import 'package:gym_progression/services/completion_storage.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/workout_storage.dart';
import 'package:gym_progression/utils/week.dart';

final RegExp _numberPattern = RegExp(r'\d+(?:[.,]\d+)?');

/// Reads the first number in a free-text weight or reps value.
/// Accepts a comma as decimal separator: "82,5 kg" -> 82.5.
double? parseMetric(String? value) {
  final match = _numberPattern.firstMatch(value ?? '');
  if (match == null) {
    return null;
  }

  return double.tryParse(match.group(0)!.replaceAll(',', '.'));
}

/// "100" for whole numbers, "102.5" otherwise.
String formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String formatVolume(double kilograms) {
  if (kilograms < 1000) {
    return '${formatNumber(kilograms)} kg';
  }

  return '${(kilograms / 1000).toStringAsFixed(1)} t';
}

/// Ids of the logs that beat every earlier weight for the same exercise.
/// The first weighted log of an exercise sets the baseline and is not a PR.
Set<int> personalRecordIds(List<ExerciseLogEntry> logs) {
  final chronological = [...logs]..sort((a, b) {
      final byDate = a.loggedAt.compareTo(b.loggedAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  final bestByExercise = <String, double>{};
  final recordIds = <int>{};

  for (final log in chronological) {
    final weight = parseMetric(log.weight);
    if (weight == null) {
      continue;
    }

    final best = bestByExercise[log.exerciseName];
    if (best != null && weight > best) {
      recordIds.add(log.id);
    }
    if (best == null || weight > best) {
      bestByExercise[log.exerciseName] = weight;
    }
  }

  return recordIds;
}

double? bestWeight(List<ExerciseLogEntry> logs) {
  final weights = logs.map((log) => parseMetric(log.weight)).whereType<double>();
  return weights.isEmpty ? null : weights.reduce(math.max);
}

/// Sum of weight x reps over the logs where both are numbers.
double totalVolume(List<ExerciseLogEntry> logs) {
  var total = 0.0;
  for (final log in logs) {
    final weight = parseMetric(log.weight);
    final reps = parseMetric(log.reps);
    if (weight != null && reps != null) {
      total += weight * reps;
    }
  }
  return total;
}

DateTime _previousMonday(DateTime monday) {
  return DateTime(monday.year, monday.month, monday.day - 7);
}

/// Consecutive weeks with at least one completed workout, up to now.
/// A current week without workouts yet doesn't break the streak: it still
/// has days left.
int currentWeekStreak(Iterable<String> weekKeys, DateTime now) {
  final weeks = weekKeys.toSet();
  var monday = mondayOf(now);

  if (!weeks.contains(weekKeyFor(monday))) {
    monday = _previousMonday(monday);
  }

  var streak = 0;
  while (weeks.contains(weekKeyFor(monday))) {
    streak++;
    monday = _previousMonday(monday);
  }

  return streak;
}

int longestWeekStreak(Iterable<String> weekKeys) {
  final mondays = weekKeys.toSet().map(mondayFromWeekKey).toList()..sort();

  var best = 0;
  var run = 0;
  DateTime? previous;

  for (final monday in mondays) {
    final followsPrevious = previous != null &&
        weekKeyFor(_previousMonday(monday)) == weekKeyFor(previous);
    run = followsPrevious ? run + 1 : 1;
    best = math.max(best, run);
    previous = monday;
  }

  return best;
}

class ProfileStats {
  const ProfileStats({
    required this.totalCompleted,
    required this.currentStreak,
    required this.bestStreak,
    required this.personalRecords,
    required this.totalVolumeKg,
    required this.plannedThisWeek,
    required this.completedThisWeek,
  });

  final int totalCompleted;
  final int currentStreak;
  final int bestStreak;
  final int personalRecords;
  final double totalVolumeKg;
  final int plannedThisWeek;
  final int completedThisWeek;

  double get weekProgress {
    return plannedThisWeek == 0
        ? 0
        : math.min(1, completedThisWeek / plannedThisWeek);
  }

  bool get isPerfectWeek {
    return plannedThisWeek > 0 && completedThisWeek >= plannedThisWeek;
  }

  static Future<ProfileStats> load(String profileId) async {
    final now = DateTime.now();
    final currentWeekKey = weekKeyFor(now);

    final workouts = await WorkoutStorage.loadWorkouts(profileId);
    final completions = await CompletionStorage.getCompletions(profileId);
    final logs = await ExerciseLogStorage.getLogsForProfile(profileId);
    final weekKeys = completions.map((completion) => completion.weekKey);

    return ProfileStats(
      totalCompleted: completions.length,
      currentStreak: currentWeekStreak(weekKeys, now),
      bestStreak: longestWeekStreak(weekKeys),
      personalRecords: personalRecordIds(logs).length,
      totalVolumeKg: totalVolume(logs),
      plannedThisWeek: workouts.length,
      completedThisWeek: workouts
          .where((workout) => workout.lastCompletedWeekKey == currentWeekKey)
          .length,
    );
  }
}
