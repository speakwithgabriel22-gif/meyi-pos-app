import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get isDarkMode => _prefs.getBool('isDarkMode') ?? false;
  static set isDarkMode(bool value) => _prefs.setBool('isDarkMode', value);

  static bool get notificationsEnabled => _prefs.getBool('notificationsEnabled') ?? true;
  static set notificationsEnabled(bool value) => _prefs.setBool('notificationsEnabled', value);
}
