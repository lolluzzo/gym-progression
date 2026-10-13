import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _darkModeKey = 'dark_mode';
  static const String _trainerModeKey = 'trainer_mode';
  static const String _setsGuideSeenKey = 'sets_guide_seen';

  bool _darkMode = false;
  bool _trainerMode = false;
  bool _setsGuideSeen = false;

  bool get darkMode => _darkMode;
  bool get trainerMode => _trainerMode;

  /// Whether the guide to logging sets was shown. It opens by itself once.
  bool get setsGuideSeen => _setsGuideSeen;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(_darkModeKey) ?? false;
    _trainerMode = prefs.getBool(_trainerModeKey) ?? false;
    _setsGuideSeen = prefs.getBool(_setsGuideSeenKey) ?? false;
  }

  Future<void> markSetsGuideSeen() async {
    _setsGuideSeen = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setsGuideSeenKey, true);
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<void> setTrainerMode(bool value) async {
    _trainerMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trainerModeKey, value);
  }
}
