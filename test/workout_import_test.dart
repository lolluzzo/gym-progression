import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/services/workout_import.dart';

/// Each workout as its name followed by its exercises.
List<List<String>> parse(String text) {
  return parseWorkoutNotes(text)
      .map((workout) => [workout.name, ...workout.exercises])
      .toList();
}

void main() {
  group('parseWorkoutNotes', () {
    test('reads one indented workout', () {
      expect(
        parse('Push day\n  - Bench press\n  - Shoulder press\n'),
        [
          ['Push day', 'Bench press', 'Shoulder press'],
        ],
      );
    });

    test('splits workouts at each name line and skips blank lines', () {
      expect(
        parse('Push:\n• Bench press\n\n\nPull\r\n1. Row\r\n2) Pull-up\r\n'),
        [
          ['Push', 'Bench press'],
          ['Pull', 'Row', 'Pull-up'],
        ],
      );
    });

    test('drops names without exercises, like a note title', () {
      expect(
        parse('My program\n\nLegs\n-Squat\n- \n...\n'),
        [
          ['Legs', 'Squat'],
        ],
      );
    });

    test('keeps a name that starts with a number', () {
      expect(
        parse('07.10 Push\n- Dips'),
        [
          ['07.10 Push', 'Dips'],
        ],
      );
    });

    test('names exercises listed before any workout name', () {
      expect(
        parse('- Plank\n- Crunch'),
        [
          ['Imported workout', 'Plank', 'Crunch'],
        ],
      );
    });

    test('finds nothing in empty or list-free text', () {
      expect(parse(''), isEmpty);
      expect(parse('Push\nPull\n'), isEmpty);
    });
  });
}
