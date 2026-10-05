import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/services/app_database.dart';

class WorkoutCompletion {
  WorkoutCompletion({
    required this.workoutId,
    required this.weekKey,
    required this.completedAt,
  });

  final String workoutId;
  final String weekKey;
  final DateTime completedAt;

  factory WorkoutCompletion.fromMap(Map<String, Object?> map) {
    return WorkoutCompletion(
      workoutId: map['workout_id'] as String,
      weekKey: map['week_key'] as String,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }
}

/// History of completed workouts: one row per workout per week.
class CompletionStorage {
  CompletionStorage._();

  static const String _table = AppDatabase.completionsTable;

  static Future<void> addCompletion({
    required String profileId,
    required Workout workout,
    required String weekKey,
  }) async {
    final db = await AppDatabase.open();
    try {
      await db.insert(_table, {
        'profile_id': profileId,
        'workout_id': workout.id,
        'workout_name': workout.name,
        'week_key': weekKey,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } finally {
      await db.close();
    }
  }

  static Future<void> removeCompletion({
    required String profileId,
    required String workoutId,
    required String weekKey,
  }) async {
    final db = await AppDatabase.open();
    try {
      await db.delete(
        _table,
        where: 'profile_id = ? AND workout_id = ? AND week_key = ?',
        whereArgs: [profileId, workoutId, weekKey],
      );
    } finally {
      await db.close();
    }
  }

  static Future<List<WorkoutCompletion>> getCompletions(
    String profileId,
  ) async {
    final db = await AppDatabase.open();
    try {
      final rows = await db.query(
        _table,
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'completed_at ASC',
      );

      return rows.map(WorkoutCompletion.fromMap).toList();
    } finally {
      await db.close();
    }
  }

  static Future<void> deleteCompletionsForProfile(String profileId) async {
    final db = await AppDatabase.open();
    try {
      await db.delete(_table, where: 'profile_id = ?', whereArgs: [profileId]);
    } finally {
      await db.close();
    }
  }
}
