import 'dart:convert';

import 'package:gym_progression/models/workout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutStorage {
  WorkoutStorage._();

  static const String _workoutsKey = 'workouts';

  static Future<List<Workout>> loadWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawWorkouts = prefs.getString(_workoutsKey);

    if (rawWorkouts == null || rawWorkouts.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(rawWorkouts) as List<dynamic>;

    return decoded
        .map((item) => Workout.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Future<void> saveWorkouts(List<Workout> workouts) async {
    final prefs = await SharedPreferences.getInstance();
    final rawWorkouts = jsonEncode(
      workouts.map((workout) => workout.toJson()).toList(),
    );

    await prefs.setString(_workoutsKey, rawWorkouts);
  }
}
