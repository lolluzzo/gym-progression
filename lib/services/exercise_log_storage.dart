import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class ExerciseLogEntry {
  ExerciseLogEntry({
    required this.id,
    required this.exerciseName,
    required this.loggedAt,
    this.weight,
    this.reps,
  });

  final int id;
  final String exerciseName;
  final String? weight;
  final String? reps;
  final DateTime loggedAt;

  factory ExerciseLogEntry.fromMap(Map<String, Object?> map) {
    String? asText(Object? value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) {
        return null;
      }
      return text;
    }

    return ExerciseLogEntry(
      id: (map['id'] as int?) ?? 0,
      exerciseName: (map['exercise_name'] as String?) ?? '',
      weight: asText(map['weight']),
      reps: asText(map['reps']),
      loggedAt: DateTime.parse(map['logged_at'] as String),
    );
  }
}

class ExerciseLogStorage {
  ExerciseLogStorage._();

  static const String _databaseName = 'workouts.db';
  static const String _tableName = 'workout_logs';

  static Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final fullPath = p.join(databasePath, _databaseName);

    return openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await _ensureSchema(db);
      },
      onOpen: (db) async {
        await _ensureSchema(db);
      },
    );
  }

  static Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_name TEXT NOT NULL,
        weight TEXT,
        reps TEXT,
        logged_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> saveLog({
    required String exerciseName,
    String? weight,
    String? reps,
  }) async {
    final db = await _openDatabase();
    try {
      await db.insert(_tableName, {
        'exercise_name': exerciseName,
        'weight': _cleanValue(weight),
        'reps': _cleanValue(reps),
        'logged_at': DateTime.now().toIso8601String(),
      });
    } finally {
      await db.close();
    }
  }

  static Future<List<ExerciseLogEntry>> getLogsForExercise(
    String exerciseName,
  ) async {
    final db = await _openDatabase();
    try {
      final rows = await db.query(
        _tableName,
        where: 'exercise_name = ?',
        whereArgs: [exerciseName],
        orderBy: 'logged_at DESC, id DESC',
      );

      return rows.map(ExerciseLogEntry.fromMap).toList();
    } finally {
      await db.close();
    }
  }

  static String? _cleanValue(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}
