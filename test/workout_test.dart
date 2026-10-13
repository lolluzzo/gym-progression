import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/models/workout.dart';

// Monday 12 October 2026.
const thisWeek = '2026-10-12';
const lastWeek = '2026-10-05';

Workout workout({
  required DateTime updatedAt,
  String? lastCompletedWeekKey,
}) {
  return Workout(
    id: 'w1',
    name: 'Push',
    updatedAt: updatedAt,
    lastCompletedWeekKey: lastCompletedWeekKey,
    exercises: [
      ExerciseEntry(
        id: 'e1',
        name: 'Bench press',
        weight: '80',
        reps: '8',
        alternatives: ['Dumbbell press'],
        chosenName: 'Dumbbell press',
      ),
      ExerciseEntry(id: 'e2', name: 'Dips', weight: '20', reps: '10'),
    ],
  );
}

void main() {
  group('Workout.forWeek', () {
    test('changes nothing in the same week', () {
      final original = workout(
        updatedAt: DateTime(2026, 10, 13, 18),
        lastCompletedWeekKey: thisWeek,
      );

      expect(original.forWeek(thisWeek), same(original));
    });

    test('clears values and completion from an earlier week', () {
      final updatedAt = DateTime(2026, 10, 11, 18);
      final reset = workout(
        updatedAt: updatedAt,
        lastCompletedWeekKey: lastWeek,
      ).forWeek(thisWeek);

      expect(reset.lastCompletedWeekKey, isNull);
      expect(reset.exercises.map((e) => e.weight), ['', '']);
      expect(reset.exercises.map((e) => e.reps), ['', '']);
      expect(reset.updatedAt, updatedAt);
      expect(reset.exercises.map((e) => e.id), ['e1', 'e2']);
      expect(reset.exercises.first.activeName, 'Dumbbell press');
    });

    test('clears values of a workout changed last week but never completed',
        () {
      final reset = workout(updatedAt: DateTime(2026, 10, 9)).forWeek(thisWeek);

      expect(reset.exercises.map((e) => e.weight), ['', '']);
      expect(reset.exercises.map((e) => e.reps), ['', '']);
    });

    test('keeps values changed this week, even with an old completion', () {
      final reset = workout(
        updatedAt: DateTime(2026, 10, 12, 7),
        lastCompletedWeekKey: lastWeek,
      ).forWeek(thisWeek);

      expect(reset.lastCompletedWeekKey, isNull);
      expect(reset.exercises.map((e) => e.weight), ['80', '20']);
    });
  });
}
