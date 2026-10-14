import 'dart:convert';

/// A workout read from a note, before it is saved.
class ImportedWorkout {
  ImportedWorkout(this.name);

  final String name;
  final List<String> exercises = [];
}

/// Asks an AI chat to rewrite the user's plan, pasted after it, into the
/// format [parseWorkoutNotes] reads.
const String workoutImportAiPrompt = '''
Convert my workout plan below into the exact format my gym app imports.

Rules:
- Write each workout name on its own line, with no symbol or number in front of it (e.g. "Push day", "Day 1 - Legs").
- Below each workout name, list its exercises, one per line, each starting with "- ".
- Write only the exercise name: no sets, reps, weights, rest times or notes.
- Put each exercise of a superset or circuit on its own line.
- Keep the workouts and exercises in the same order and language as my plan.
- Leave one empty line between workouts.
- Use plain text: no bold, headings or emojis.
- Reply with only the converted plan inside a single code block, with no other text before or after it.

Example:
```
Push day
- Bench press
- Shoulder press

Pull day
- Pull-up
- Barbell row
```

My workout plan:

''';

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
