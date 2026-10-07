import 'dart:convert';

/// A workout read from a note, before it is saved.
class ImportedWorkout {
  ImportedWorkout(this.name);

  final String name;
  final List<String> exercises = [];
}

// "- Bench press", "• Bench press", "1. Bench press", "2) Squat".
// A number needs a space after it, so a header like "07.10 Push" stays a
// header.
final RegExp _listItemPattern = RegExp(r'^(?:[-*•–—◦▪·]\s*|\d+[.)]\s+)(.*)$');

/// Reads workouts from a note written as:
///
///     Push day
///       - Bench press
///       - Shoulder press
///
/// A list item is an exercise of the workout above it, and any other line
/// starts a new workout. Workouts without exercises are dropped, so a note
/// title above the first workout is ignored.
List<ImportedWorkout> parseWorkoutNotes(String text) {
  final workouts = <ImportedWorkout>[];
  ImportedWorkout? current;

  for (final rawLine in const LineSplitter().convert(text)) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }

    final item = _listItemPattern.firstMatch(line);
    if (item == null) {
      final name =
          line.endsWith(':') ? line.substring(0, line.length - 1).trim() : line;
      current = ImportedWorkout(name);
      workouts.add(current);
      continue;
    }

    final exercise = item.group(1)!.trim();
    if (exercise.isEmpty) {
      continue;
    }

    if (current == null) {
      current = ImportedWorkout('Imported workout');
      workouts.add(current);
    }
    current.exercises.add(exercise);
  }

  return workouts.where((workout) => workout.exercises.isNotEmpty).toList();
}
