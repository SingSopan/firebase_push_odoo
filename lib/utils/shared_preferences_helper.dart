import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/firebase_token_model.dart';
import '../utils/constants.dart';

class SharedPreferencesHelper {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('SharedPreferencesHelper not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // Firebase Token Management
  static Future<void> saveFirebaseToken(String token) async {
    await prefs.setString(Constants.keyFirebaseToken, token);
    await prefs.setString(Constants.keyLastTokenUpdate, DateTime.now().toIso8601String());
  }

  static String? getFirebaseToken() {
    return prefs.getString(Constants.keyFirebaseToken);
  }

  static Future<void> clearFirebaseToken() async {
    await prefs.remove(Constants.keyFirebaseToken);
    await prefs.remove(Constants.keyLastTokenUpdate);
  }

  // User Session Management
  static Future<void> saveUserSession({
    required int userId,
    required String userName,
  }) async {
    await prefs.setInt(Constants.keyUserId, userId);
    await prefs.setString(Constants.keyUserName, userName);
    await prefs.setBool(Constants.keyIsLoggedIn, true);
  }

  static Future<void> clearUserSession() async {
    await prefs.remove(Constants.keyUserId);
    await prefs.remove(Constants.keyUserName);
    await prefs.setBool(Constants.keyIsLoggedIn, false);
  }

  static int? getUserId() {
    return prefs.getInt(Constants.keyUserId);
  }

  static String? getUserName() {
    return prefs.getString(Constants.keyUserName);
  }

  static bool isLoggedIn() {
    return prefs.getBool(Constants.keyIsLoggedIn) ?? false;
  }

  // Device OS
  static Future<void> saveDeviceOS(String os) async {
    await prefs.setString(Constants.keyDeviceOS, os);
  }

  static String getDeviceOS() {
    return prefs.getString(Constants.keyDeviceOS) ?? Constants.deviceOS;
  }

  // Token Update Tracking
  static DateTime? getLastTokenUpdate() {
    final dateString = prefs.getString(Constants.keyLastTokenUpdate);
    if (dateString != null) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Complete Token Model Storage
  static Future<void> saveTokenModel(FirebaseTokenModel tokenModel) async {
    final jsonString = jsonEncode(tokenModel.toJson());
    await prefs.setString('${Constants.keyFirebaseToken}_model', jsonString);
  }

  static FirebaseTokenModel? getTokenModel() {
    final jsonString = prefs.getString('${Constants.keyFirebaseToken}_model');
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return FirebaseTokenModel.fromJson(json);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Utility Methods
  static Future<void> clearAll() async {
    await prefs.clear();
  }

  static Future<void> clearAppData() async {
    await clearFirebaseToken();
    await clearUserSession();
  }

  // Check if token needs refresh (example: if older than 24 hours)
  static bool shouldRefreshToken() {
    final lastUpdate = getLastTokenUpdate();
    if (lastUpdate == null) return true;
    
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);
    return difference.inHours >= 24;
  }

  // Debug Helper
  static Map<String, dynamic> getAllStoredData() {
    final keys = prefs.getKeys();
    final data = <String, dynamic>{};
    
    for (String key in keys) {
      data[key] = prefs.get(key);
    }
    
    return data;
  }
}