import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/utils/exercise_name.dart';

/// The [exerciseKey] of every exercise and alternative in [workouts].
Set<String> exerciseKeysIn(Iterable<Workout> workouts) {
  return {
    for (final workout in workouts)
      for (final exercise in workout.exercises)
        for (final form in exercise.forms) exerciseKey(form),
  };
}

/// Exercises that kept their id but got a new name. A change of case or
/// spacing isn't a rename: the logs already match the new name.
List<({String from, String to})> renamedExercises(
  Workout before,
  Workout after,
) {
  final previousNames = {
    for (final exercise in before.exercises) exercise.id: exercise.name,
  };

  return [
    for (final exercise in after.exercises)
      if (previousNames[exercise.id] case final from?
          when exerciseKey(from) != exerciseKey(exercise.name))
        (from: from, to: exercise.name),
  ];
}

/// Logs of exercises that aren't in any of [workouts], as a name or an
/// alternative. [logs] must be oldest first, as
/// [ExerciseLogStorage.getLogsForProfile] returns them.
///
/// Grouped by exercise under its latest spelling, with the most recently
/// logged exercise first. Each group stays oldest first.
Map<String, List<ExerciseLogEntry>> unlinkedExercises(
  List<ExerciseLogEntry> logs,
  List<Workout> workouts,
) {
  final usedKeys = exerciseKeysIn(workouts);
  final byKey = <String, List<ExerciseLogEntry>>{};
  for (final log in logs) {
    final key = exerciseKey(log.exerciseName);
    if (!usedKeys.contains(key)) {
      byKey.putIfAbsent(key, () => []).add(log);
    }
  }

  final groups = byKey.values.toList()
    ..sort((a, b) => b.last.loggedAt.compareTo(a.last.loggedAt));
  return {for (final group in groups) group.last.exerciseName: group};
}
