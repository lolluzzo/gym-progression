import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/services/app_database.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('gym_progression_upgrade').path,
    );
  });

  test('a v3 database upgrades with every old log as a working set', () async {
    final path = p.join(await databaseFactory.getDatabasesPath(), 'workouts.db');
    final v3 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) => db.execute('''
          CREATE TABLE ${AppDatabase.logsTable} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exercise_name TEXT NOT NULL,
            weight TEXT,
            reps TEXT,
            logged_at TEXT NOT NULL,
            profile_id TEXT NOT NULL DEFAULT 'me',
            workout_id TEXT,
            workout_name TEXT
          )
        '''),
      ),
    );
    await v3.insert(AppDatabase.logsTable, {
      'exercise_name': 'Bench press',
      'weight': '80',
      'reps': '8',
      'logged_at': DateTime(2026, 10, 7, 18).toIso8601String(),
      'profile_id': 'p1',
      'workout_id': 'w1',
      'workout_name': 'Push A',
    });
    await v3.close();

    final logs = await ExerciseLogStorage.getLogsForProfile('p1');

    expect(logs, hasLength(1));
    expect(logs.single.weight, '80');
    expect(logs.single.isWarmup, isFalse);
  });
}
