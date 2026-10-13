import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/services/app_database.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> saveLog(String profileId, String exerciseName) {
  return ExerciseLogStorage.saveLog(
    profileId: profileId,
    exerciseName: exerciseName,
    weight: '80',
  );
}

Future<List<String>> namesFor(String profileId) async {
  final logs = await ExerciseLogStorage.getLogsForProfile(profileId);
  return logs.map((log) => log.exerciseName).toList();
}

Future<List<int>> saveBenchSets(
  List<SetToSave> sets, {
  List<int> deletedIds = const [],
}) {
  return ExerciseLogStorage.saveSets(
    profileId: 'p1',
    exerciseName: 'Bench press',
    sets: sets,
    deletedIds: deletedIds,
    workoutId: 'w1',
    workoutName: 'Push A',
  );
}

Future<List<ExerciseLogEntry>> todaysSets() {
  return ExerciseLogStorage.getSetsForDay('p1', 'w1', DateTime.now());
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('gym_progression_logs').path,
    );
  });

  setUp(() async {
    await ExerciseLogStorage.deleteLogsForProfile('p1');
    await ExerciseLogStorage.deleteLogsForProfile('p2');
    await saveLog('p1', 'Panca');
    await saveLog('p1', 'PANCA');
    await saveLog('p1', 'Squat');
    await saveLog('p2', 'Panca');
  });

  test('getLogsForExercise matches any case and spacing', () async {
    final logs = await ExerciseLogStorage.getLogsForExercise('p1', 'panca ');

    expect(logs.map((log) => log.exerciseName), ['PANCA', 'Panca']);
  });

  test('renameExercise moves only that profile\'s logs of that exercise',
      () async {
    final moved =
        await ExerciseLogStorage.renameExercise('p1', 'panca', 'Bench press');

    expect(moved, 2);
    expect(await namesFor('p1'), ['Bench press', 'Bench press', 'Squat']);
    expect(await namesFor('p2'), ['Panca']);
  });

  test('renameExercise moves nothing for a name without logs', () async {
    expect(await ExerciseLogStorage.renameExercise('p1', 'Row', 'Rows'), 0);
    expect(await namesFor('p1'), ['Panca', 'PANCA', 'Squat']);
  });

  test('deleteLogsForExercise deletes only that profile\'s logs of it',
      () async {
    final deleted =
        await ExerciseLogStorage.deleteLogsForExercise('p1', 'Panca');

    expect(deleted, 2);
    expect(await namesFor('p1'), ['Squat']);
    expect(await namesFor('p2'), ['Panca']);
  });

  test('saveSets edits and removes sets in place, keeping ids and times',
      () async {
    final ids = await saveBenchSets(const [
      SetToSave(weight: '80', reps: '8'),
      SetToSave(weight: '85', reps: '6'),
      SetToSave(weight: '85', reps: '5'),
    ]);
    final before = await todaysSets();

    final saved = await saveBenchSets(
      [SetToSave(id: ids[1], weight: '87.5', reps: '6')],
      deletedIds: [ids[2]],
    );
    final after = await todaysSets();

    expect(saved, [ids[1]]);
    expect(after.map((log) => log.id), ids.take(2));
    expect(
      after.map((log) => log.loggedAt),
      before.take(2).map((log) => log.loggedAt),
    );
    expect(after.map((log) => log.weight), ['80', '87.5']);
    expect(after.map((log) => log.workoutName), ['Push A', 'Push A']);
  });

  test('saveSets keeps the warm-up flag and only the values given', () async {
    final ids = await saveBenchSets(const [
      SetToSave(weight: '60', reps: '10', isWarmup: true),
      SetToSave(weight: '80'),
    ]);
    await saveBenchSets(
      [SetToSave(id: ids[0], weight: '60', reps: '12', isWarmup: true)],
    );

    final sets = await todaysSets();

    expect(sets.map((log) => log.isWarmup), [true, false]);
    expect(sets.map((log) => log.reps), ['12', null]);
  });

  test('getSetsForDay returns only that profile, workout and day', () async {
    final ids = await saveBenchSets(const [SetToSave(weight: '80', reps: '8')]);
    await ExerciseLogStorage.saveSets(
      profileId: 'p1',
      exerciseName: 'Squat',
      sets: const [SetToSave(weight: '100', reps: '5')],
      workoutId: 'w2',
    );
    await ExerciseLogStorage.saveSets(
      profileId: 'p2',
      exerciseName: 'Bench press',
      sets: const [SetToSave(weight: '50', reps: '5')],
      workoutId: 'w1',
    );
    final db = await AppDatabase.open();
    await db.insert(AppDatabase.logsTable, {
      'profile_id': 'p1',
      'exercise_name': 'Bench press',
      'weight': '75',
      'logged_at': DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
      'workout_id': 'w1',
    });
    await db.close();

    expect((await todaysSets()).map((log) => log.id), ids);
  });
}
