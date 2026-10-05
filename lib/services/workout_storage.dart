import 'dart:convert';

import 'package:gym_progression/models/profile.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutStorage {
  WorkoutStorage._();

  static const String _workoutsKey = 'workouts';

  // The owner keeps the original key, so workouts saved before profiles
  // existed are still found.
  static String _keyFor(String profileId) {
    return profileId == Profile.ownerId
        ? _workoutsKey
        : '${_workoutsKey}_$profileId';
  }

  static Future<List<Workout>> loadWorkouts(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawWorkouts = prefs.getString(_keyFor(profileId));

    if (rawWorkouts == null || rawWorkouts.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(rawWorkouts) as List<dynamic>;

    return decoded
        .map((item) => Workout.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Future<void> saveWorkouts(
    String profileId,
    List<Workout> workouts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rawWorkouts = jsonEncode(
      workouts.map((workout) => workout.toJson()).toList(),
    );

    await prefs.setString(_keyFor(profileId), rawWorkouts);
  }

  static Future<void> deleteWorkouts(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(profileId));
  }
}
