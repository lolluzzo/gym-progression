import 'dart:convert';
import 'dart:io';

import 'package:gym_progression/models/profile.dart';
import 'package:gym_progression/services/completion_storage.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/workout_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileStorage {
  ProfileStorage._();

  static const String _profilesKey = 'profiles';
  static const String _activeProfileKey = 'active_profile_id';

  static Future<List<Profile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final imagesDirectory = await _imagesDirectory();
    final rawProfiles = prefs.getString(_profilesKey);

    final profiles = rawProfiles == null || rawProfiles.isEmpty
        ? <Profile>[]
        : (jsonDecode(rawProfiles) as List<dynamic>)
            .map((item) => Profile.fromJson(
                  item as Map<String, dynamic>,
                  imagesDirectory: imagesDirectory,
                ))
            .toList();

    if (!profiles.any((profile) => profile.isOwner)) {
      profiles.insert(0, Profile(id: Profile.ownerId, name: 'Me'));
    }

    return profiles;
  }

  static Future<void> saveProfiles(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final rawProfiles = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );

    await prefs.setString(_profilesKey, rawProfiles);
  }

  /// Returns the profile with [profileId], or the owner if it doesn't exist.
  static Future<Profile> loadProfile(String? profileId) async {
    final profiles = await loadProfiles();

    return profiles.firstWhere(
      (profile) => profile.id == profileId,
      orElse: () => profiles.firstWhere((profile) => profile.isOwner),
    );
  }

  static Future<void> saveProfile(Profile profile) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((item) => item.id == profile.id);

    if (index == -1) {
      profiles.add(profile);
    } else {
      profiles[index] = profile;
    }

    await saveProfiles(profiles);
  }

  /// Removes a client together with its workouts, logs, history and photo.
  static Future<void> deleteProfile(Profile profile) async {
    final profiles = await loadProfiles();
    await saveProfiles(
      profiles.where((item) => item.id != profile.id).toList(),
    );

    await WorkoutStorage.deleteWorkouts(profile.id);
    await ExerciseLogStorage.deleteLogsForProfile(profile.id);
    await CompletionStorage.deleteCompletionsForProfile(profile.id);
    await deleteImage(profile.imagePath);

    if (await loadActiveProfileId() == profile.id) {
      await setActiveProfileId(Profile.ownerId);
    }
  }

  static Future<String?> loadActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  static Future<void> setActiveProfileId(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profileId);
  }

  /// Copies a picked image into the app documents directory.
  /// The timestamp in the name makes Flutter drop the cached old image.
  static Future<String> saveImage(String profileId, String sourcePath) async {
    final imagesDirectory = await _imagesDirectory();
    final targetPath = p.join(
      imagesDirectory,
      'profile_${profileId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}',
    );

    await File(sourcePath).copy(targetPath);
    return targetPath;
  }

  static Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null) {
      return;
    }

    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<String> _imagesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
}
