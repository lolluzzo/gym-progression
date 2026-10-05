import 'package:gym_progression/services/app_database.dart';
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

  static const String _tableName = AppDatabase.logsTable;

  static Future<Database> _openDatabase() => AppDatabase.open();

  static Future<void> saveLog({
    required String profileId,
    required String exerciseName,
    String? weight,
    String? reps,
  }) async {
    final db = await _openDatabase();
    try {
      await db.insert(_tableName, {
        'profile_id': profileId,
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
    String profileId,
    String exerciseName,
  ) async {
    final db = await _openDatabase();
    try {
      final rows = await db.query(
        _tableName,
        where: 'profile_id = ? AND exercise_name = ?',
        whereArgs: [profileId, exerciseName],
        orderBy: 'logged_at DESC, id DESC',
      );

      return rows.map(ExerciseLogEntry.fromMap).toList();
    } finally {
      await db.close();
    }
  }

  static Future<List<ExerciseLogEntry>> getLogsForProfile(
    String profileId,
  ) async {
    final db = await _openDatabase();
    try {
      final rows = await db.query(
        _tableName,
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'logged_at ASC, id ASC',
      );

      return rows.map(ExerciseLogEntry.fromMap).toList();
    } finally {
      await db.close();
    }
  }

  static Future<void> deleteLog(int id) async {
    final db = await _openDatabase();
    try {
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    } finally {
      await db.close();
    }
  }

  static Future<void> deleteLogsForProfile(String profileId) async {
    final db = await _openDatabase();
    try {
      await db.delete(
        _tableName,
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
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
