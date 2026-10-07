import 'package:gym_progression/services/exercise_log_storage.dart';

/// One training: the logs saved from a workout on the same day.
class TrainingSession {
  TrainingSession({required this.day, this.workoutName});

  /// Local midnight of the training day.
  final DateTime day;

  /// Null for logs saved before logs remembered their workout.
  final String? workoutName;

  /// Oldest first.
  final List<ExerciseLogEntry> logs = [];

  /// Each exercise's logs, in the order the exercises were first logged.
  Map<String, List<ExerciseLogEntry>> get logsByExercise {
    final byExercise = <String, List<ExerciseLogEntry>>{};
    for (final log in logs) {
      byExercise.putIfAbsent(log.exerciseName, () => []).add(log);
    }
    return byExercise;
  }
}

/// Groups logs by day and workout, latest session first. Logs without a
/// workout share one session per day.
List<TrainingSession> groupSessions(List<ExerciseLogEntry> logs) {
  final chronological = [...logs]..sort((a, b) {
      final byDate = a.loggedAt.compareTo(b.loggedAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  final sessions = <String, TrainingSession>{};
  for (final log in chronological) {
    final local = log.loggedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final key = '${day.toIso8601String()} ${log.workoutId ?? ''}';

    sessions
        .putIfAbsent(
          key,
          () => TrainingSession(day: day, workoutName: log.workoutName),
        )
        .logs
        .add(log);
  }

  return sessions.values.toList().reversed.toList();
}
