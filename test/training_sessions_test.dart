import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/training_sessions.dart';

ExerciseLogEntry log(
  int id,
  String exercise,
  String loggedAt, {
  String? workoutId,
  String? workoutName,
}) {
  return ExerciseLogEntry(
    id: id,
    exerciseName: exercise,
    loggedAt: DateTime.parse(loggedAt),
    workoutId: workoutId,
    workoutName: workoutName,
  );
}

void main() {
  group('groupSessions', () {
    test('groups by day and workout, latest session first', () {
      final sessions = groupSessions([
        log(1, 'Bench', '2026-10-05T18:00:00',
            workoutId: 'a', workoutName: 'Push'),
        log(2, 'Squat', '2026-10-05T19:00:00',
            workoutId: 'b', workoutName: 'Legs'),
        log(3, 'Bench', '2026-10-05T18:10:00',
            workoutId: 'a', workoutName: 'Push'),
        log(4, 'Bench', '2026-10-07T18:00:00',
            workoutId: 'a', workoutName: 'Push'),
      ]);

      expect(
        sessions.map((session) => (session.day, session.workoutName)),
        [
          (DateTime(2026, 10, 7), 'Push'),
          (DateTime(2026, 10, 5), 'Legs'),
          (DateTime(2026, 10, 5), 'Push'),
        ],
      );
      expect(sessions[2].logs.map((log) => log.id), [1, 3]);
    });

    test('puts logs without a workout in one session per day', () {
      final sessions = groupSessions([
        log(1, 'Bench', '2026-10-05T08:00:00'),
        log(2, 'Row', '2026-10-05T21:00:00'),
      ]);

      expect(sessions, hasLength(1));
      expect(sessions.single.workoutName, isNull);
    });

    test('orders exercises by their first log', () {
      final session = groupSessions([
        log(1, 'Row', '2026-10-05T18:00:00', workoutId: 'a'),
        log(2, 'Bench', '2026-10-05T18:05:00', workoutId: 'a'),
        log(3, 'Row', '2026-10-05T18:10:00', workoutId: 'a'),
      ]).single;

      expect(session.logsByExercise.keys, ['Row', 'Bench']);
      expect(session.logsByExercise['Row']!.map((log) => log.id), [1, 3]);
    });

    test('returns no sessions for no logs', () {
      expect(groupSessions([]), isEmpty);
    });
  });
}
