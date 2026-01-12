import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('secure_$key');
  }

  static Future<void> write({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('secure_$key', value);
  }

  static Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('secure_$key');
  }
}