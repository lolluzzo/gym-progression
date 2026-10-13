import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
