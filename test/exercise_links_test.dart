import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/services/exercise_links.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/utils/exercise_name.dart';

Workout workout(List<ExerciseEntry> exercises) {
  return Workout(
    id: 'w1',
    name: 'Push',
    updatedAt: DateTime(2026, 10, 13),
    exercises: exercises,
  );
}

ExerciseLogEntry log(int id, String exercise, String loggedAt) {
  return ExerciseLogEntry(
    id: id,
    exerciseName: exercise,
    loggedAt: DateTime.parse(loggedAt),
  );
}

void main() {
  test('exerciseKey ignores case and extra spaces', () {
    expect(exerciseKey(' Bench   Press '), 'bench press');
    expect(exerciseKey('Bench press'), exerciseKey('bench  press'));
    expect(exerciseKey('Bench press'), isNot(exerciseKey('Benchpress')));
  });

  group('renamedExercises', () {
    final before = workout([
      ExerciseEntry(id: 'e1', name: 'Panca'),
      ExerciseEntry(id: 'e2', name: 'Squat'),
      ExerciseEntry(id: 'e3', name: 'Row'),
    ]);

    test('finds an exercise that kept its id and got a new name', () {
      final after = workout([
        ExerciseEntry(id: 'e1', name: 'Bench press'),
        ExerciseEntry(id: 'e2', name: 'Squat'),
        ExerciseEntry(id: 'e3', name: 'Row'),
      ]);

      expect(renamedExercises(before, after), [
        (from: 'Panca', to: 'Bench press'),
      ]);
    });

    test('ignores removed, reordered, added and unchanged exercises', () {
      final after = workout([
        ExerciseEntry(id: 'e3', name: 'Row'),
        ExerciseEntry(id: 'e1', name: 'Panca'),
        ExerciseEntry(id: 'e4', name: 'Lunge'),
      ]);

      expect(renamedExercises(before, after), isEmpty);
    });

    test('ignores a change of case or spacing', () {
      final after = workout([
        ExerciseEntry(id: 'e1', name: 'panca'),
        ExerciseEntry(id: 'e2', name: 'Squat '),
        ExerciseEntry(id: 'e3', name: 'Row'),
      ]);

      expect(renamedExercises(before, after), isEmpty);
    });
  });

  group('unlinkedExercises', () {
    final workouts = [
      workout([
        ExerciseEntry(
          id: 'e1',
          name: 'Bench press',
          alternatives: ['Dumbbell press'],
        ),
      ]),
    ];

    test('counts names and alternatives as used, in any case', () {
      final logs = [
        log(1, 'bench press', '2026-10-01T10:00:00'),
        log(2, 'Dumbbell Press', '2026-10-02T10:00:00'),
        log(3, 'Panca', '2026-10-03T10:00:00'),
      ];

      expect(unlinkedExercises(logs, workouts).keys, ['Panca']);
    });

    test('groups spellings under the latest one, most recent first', () {
      final logs = [
        log(1, 'panca', '2026-10-01T10:00:00'),
        log(2, 'Lat machine', '2026-10-02T10:00:00'),
        log(3, 'Panca', '2026-10-03T10:00:00'),
        log(4, 'Lat machine', '2026-10-07T10:00:00'),
      ];

      final unlinked = unlinkedExercises(logs, workouts);

      expect(unlinked.keys, ['Lat machine', 'Panca']);
      expect(unlinked['Panca']!.map((log) => log.id), [1, 3]);
    });

    test('is empty when every log belongs to a workout', () {
      final logs = [log(1, 'Bench press', '2026-10-01T10:00:00')];

      expect(unlinkedExercises(logs, workouts), isEmpty);
    });
  });
}
