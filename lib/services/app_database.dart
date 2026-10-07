import 'package:gym_progression/models/profile.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static const String _databaseName = 'workouts.db';
  static const String logsTable = 'workout_logs';
  static const String completionsTable = 'workout_completions';

  static Future<Database> open() async {
    final databasePath = await getDatabasesPath();
    final fullPath = p.join(databasePath, _databaseName);

    return openDatabase(
      fullPath,
      version: 3,
      onCreate: (db, version) async {
        await _ensureSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2: logs belong to a profile. Existing logs go to the owner.
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $logsTable ADD COLUMN profile_id TEXT NOT NULL DEFAULT '${Profile.ownerId}'",
          );
        }
        // v3: logs remember their workout, so history can group them into
        // sessions. Existing logs have no workout.
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $logsTable ADD COLUMN workout_id TEXT');
          await db
              .execute('ALTER TABLE $logsTable ADD COLUMN workout_name TEXT');
        }
      },
      onOpen: (db) async {
        await _ensureSchema(db);
      },
    );
  }

  static Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $logsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_name TEXT NOT NULL,
        weight TEXT,
        reps TEXT,
        logged_at TEXT NOT NULL,
        profile_id TEXT NOT NULL DEFAULT '${Profile.ownerId}',
        workout_id TEXT,
        workout_name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $completionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL,
        workout_id TEXT NOT NULL,
        workout_name TEXT NOT NULL,
        week_key TEXT NOT NULL,
        completed_at TEXT NOT NULL
      )
    ''');
  }
}
