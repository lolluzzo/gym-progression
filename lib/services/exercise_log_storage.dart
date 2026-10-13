import 'package:gym_progression/services/app_database.dart';
import 'package:gym_progression/utils/exercise_name.dart';
import 'package:sqflite/sqflite.dart';

class ExerciseLogEntry {
  ExerciseLogEntry({
    required this.id,
    required this.exerciseName,
    required this.loggedAt,
    this.weight,
    this.reps,
    this.workoutId,
    this.workoutName,
    this.isWarmup = false,
  });

  final int id;
  final String exerciseName;
  final String? weight;
  final String? reps;
  final DateTime loggedAt;

  /// The workout the log was saved from. Null for logs saved before logs
  /// remembered their workout.
  final String? workoutId;
  final String? workoutName;

  /// Warm-up sets are kept out of PRs and stats.
  final bool isWarmup;

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
      workoutId: map['workout_id'] as String?,
      workoutName: map['workout_name'] as String?,
      isWarmup: map['is_warmup'] == 1,
    );
  }
}

/// A set to save. [id] is its log id, or null for a set not saved yet.
class SetToSave {
  const SetToSave({this.id, this.weight, this.reps, this.isWarmup = false});

  final int? id;
  final String? weight;
  final String? reps;
  final bool isWarmup;
}

class ExerciseLogStorage {
  ExerciseLogStorage._();

  static const String _tableName = AppDatabase.logsTable;

  static Future<Database> _openDatabase() => AppDatabase.open();

  /// Saves the sets of one exercise in one transaction. A set with an id
  /// updates its log in place and keeps its time. A set without one is
  /// inserted. The logs in [deletedIds] are deleted. Returns the log id of
  /// each set, in the order of [sets].
  static Future<List<int>> saveSets({
    required String profileId,
    required String exerciseName,
    required List<SetToSave> sets,
    List<int> deletedIds = const [],
    String? workoutId,
    String? workoutName,
  }) async {
    final db = await _openDatabase();
    try {
      return await db.transaction((txn) async {
        if (deletedIds.isNotEmpty) {
          await txn.delete(
            _tableName,
            where: 'profile_id = ? AND id IN (${_placeholders(deletedIds)})',
            whereArgs: [profileId, ...deletedIds],
          );
        }

        final ids = <int>[];
        for (final set in sets) {
          final values = {
            'weight': _cleanValue(set.weight),
            'reps': _cleanValue(set.reps),
            'is_warmup': set.isWarmup ? 1 : 0,
          };
          final id = set.id;
          if (id != null) {
            await txn.update(
              _tableName,
              values,
              where: 'profile_id = ? AND id = ?',
              whereArgs: [profileId, id],
            );
            ids.add(id);
          } else {
            ids.add(await txn.insert(_tableName, {
              ...values,
              'profile_id': profileId,
              'exercise_name': exerciseName,
              'logged_at': DateTime.now().toIso8601String(),
              'workout_id': workoutId,
              'workout_name': workoutName,
            }));
          }
        }
        return ids;
      });
    } finally {
      await db.close();
    }
  }

  /// The sets saved from [workoutId] on the same local day as [day], in the
  /// order they were added. Reopening a workout continues from them.
  static Future<List<ExerciseLogEntry>> getSetsForDay(
    String profileId,
    String workoutId,
    DateTime day,
  ) async {
    // logged_at is a local ISO 8601 string, so the day compares as text.
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final db = await _openDatabase();
    try {
      final rows = await db.query(
        _tableName,
        where: 'profile_id = ? AND workout_id = ? '
            'AND logged_at >= ? AND logged_at < ?',
        whereArgs: [
          profileId,
          workoutId,
          start.toIso8601String(),
          end.toIso8601String(),
        ],
        orderBy: 'id ASC',
      );

      return rows.map(ExerciseLogEntry.fromMap).toList();
    } finally {
      await db.close();
    }
  }

  /// The logs of [exerciseName] under any spelling with the same
  /// [exerciseKey], latest first.
  static Future<List<ExerciseLogEntry>> getLogsForExercise(
    String profileId,
    String exerciseName,
  ) async {
    final db = await _openDatabase();
    try {
      final names = await _storedNames(db, profileId, exerciseName);
      if (names.isEmpty) {
        return [];
      }

      final rows = await db.query(
        _tableName,
        where: 'profile_id = ? AND exercise_name IN (${_placeholders(names)})',
        whereArgs: [profileId, ...names],
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

  /// Moves the logs of [from] to the name [to]. Returns the number of logs
  /// moved. When [to] already has logs, the two histories merge.
  static Future<int> renameExercise(
    String profileId,
    String from,
    String to,
  ) async {
    final db = await _openDatabase();
    try {
      final names = await _storedNames(db, profileId, from);
      if (names.isEmpty) {
        return 0;
      }

      return await db.update(
        _tableName,
        {'exercise_name': to},
        where: 'profile_id = ? AND exercise_name IN (${_placeholders(names)})',
        whereArgs: [profileId, ...names],
      );
    } finally {
      await db.close();
    }
  }

  /// Returns the number of logs deleted.
  static Future<int> deleteLogsForExercise(
    String profileId,
    String exerciseName,
  ) async {
    final db = await _openDatabase();
    try {
      final names = await _storedNames(db, profileId, exerciseName);
      if (names.isEmpty) {
        return 0;
      }

      return await db.delete(
        _tableName,
        where: 'profile_id = ? AND exercise_name IN (${_placeholders(names)})',
        whereArgs: [profileId, ...names],
      );
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

  /// The spellings of [exerciseName] the profile's logs use. SQLite's
  /// lower() only folds ASCII, so the names are matched here.
  static Future<List<String>> _storedNames(
    Database db,
    String profileId,
    String exerciseName,
  ) async {
    final key = exerciseKey(exerciseName);
    final rows = await db.query(
      _tableName,
      distinct: true,
      columns: ['exercise_name'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );

    return [
      for (final row in rows)
        if (exerciseKey(row['exercise_name'] as String) == key)
          row['exercise_name'] as String,
    ];
  }

  static String _placeholders(List<Object> values) {
    return List.filled(values.length, '?').join(', ');
  }

  static String? _cleanValue(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}
