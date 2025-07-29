import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_odoo_push/utils/constants.dart';
import 'package:webview_odoo_push/utils/app_utils.dart';
import 'package:flutter/foundation.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  String? _sessionCookies;
  int? _userId;
  String? _userName;
  String? _sessionId;
  bool _isLoggedIn = false;
  DateTime? _lastLoginTime;

  /// Initialize session manager and load saved session data
  Future<void> initialize() async {
    await _loadSessionFromStorage();
    AppUtils.logInfo('Session Manager initialized');
  }

  /// Load session data from storage
  Future<void> _loadSessionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _sessionCookies = prefs.getString(Constants.keySessionCookies);
      _userId = prefs.getInt(Constants.keyUserId);
      _userName = prefs.getString(Constants.keyUserName);
      _isLoggedIn = prefs.getBool(Constants.keyUserLoggedIn) ?? false;
      
      final lastLoginStr = prefs.getString('last_login_time');
      if (lastLoginStr != null) {
        _lastLoginTime = DateTime.parse(lastLoginStr);
      }

      // Extract session ID from cookies if available
      if (_sessionCookies != null) {
        _sessionId = AppUtils.extractSessionId(_sessionCookies!);
      }

      // Validate session
      if (_isLoggedIn && !_isSessionValid()) {
        await clearSession();
      }

      AppUtils.logInfo('Session data loaded from storage');
    } catch (e) {
      AppUtils.logError('Loading session from storage', e);
    }
  }

  /// Save session data to storage
  Future<void> _saveSessionToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_sessionCookies != null) {
        await prefs.setString(Constants.keySessionCookies, _sessionCookies!);
      }
      
      if (_userId != null) {
        await prefs.setInt(Constants.keyUserId, _userId!);
      }
      
      if (_userName != null) {
        await prefs.setString(Constants.keyUserName, _userName!);
      }
      
      await prefs.setBool(Constants.keyUserLoggedIn, _isLoggedIn);
      
      if (_lastLoginTime != null) {
        await prefs.setString('last_login_time', _lastLoginTime!.toIso8601String());
      }

      AppUtils.logInfo('Session data saved to storage');
    } catch (e) {
      AppUtils.logError('Saving session to storage', e);
    }
  }

  /// Set session after successful login
  Future<void> setSession({
    required String cookies,
    int? userId,
    String? userName,
  }) async {
    _sessionCookies = cookies;
    _userId = userId;
    _userName = userName;
    _isLoggedIn = true;
    _lastLoginTime = DateTime.now();
    _sessionId = AppUtils.extractSessionId(cookies);

    await _saveSessionToStorage();
    AppUtils.logInfo('Session set successfully for user: $userName');
  }

  /// Update session cookies
  Future<void> updateSessionCookies(String cookies) async {
    if (_isLoggedIn) {
      _sessionCookies = cookies;
      _sessionId = AppUtils.extractSessionId(cookies);
      await _saveSessionToStorage();
      AppUtils.logInfo('Session cookies updated');
    }
  }

  /// Update user info
  Future<void> updateUserInfo({int? userId, String? userName}) async {
    if (_isLoggedIn) {
      if (userId != null) _userId = userId;
      if (userName != null) _userName = userName;
      await _saveSessionToStorage();
      AppUtils.logInfo('User info updated');
    }
  }

  /// Clear session data
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove session-related keys
      await prefs.remove(Constants.keySessionCookies);
      await prefs.remove(Constants.keyUserId);
      await prefs.remove(Constants.keyUserName);
      await prefs.remove(Constants.keyUserLoggedIn);
      await prefs.remove('last_login_time');

      // Clear in-memory data
      _sessionCookies = null;
      _userId = null;
      _userName = null;
      _sessionId = null;
      _isLoggedIn = false;
      _lastLoginTime = null;

      AppUtils.logInfo('Session cleared successfully');
    } catch (e) {
      AppUtils.logError('Clearing session', e);
    }
  }

  /// Check if session is valid
  bool _isSessionValid() {
    if (!_isLoggedIn || _sessionCookies == null || _sessionCookies!.isEmpty) {
      return false;
    }

    // Check if session is not too old (7 days)
    if (_lastLoginTime != null) {
      final sessionAge = DateTime.now().difference(_lastLoginTime!);
      if (sessionAge.inDays > 7) {
        AppUtils.logWarning('Session expired due to age');
        return false;
      }
    }

    return true;
  }

  /// Check if user is currently logged in
  bool get isLoggedIn => _isLoggedIn && _isSessionValid();

  /// Get session cookies
  String? get sessionCookies => _isLoggedIn ? _sessionCookies : null;

  /// Get user ID
  int? get userId => _isLoggedIn ? _userId : null;

  /// Get user name
  String? get userName => _isLoggedIn ? _userName : null;

  /// Get session ID
  String? get sessionId => _isLoggedIn ? _sessionId : null;

  /// Get last login time
  DateTime? get lastLoginTime => _lastLoginTime;

  /// Get session duration
  Duration? get sessionDuration {
    if (_lastLoginTime != null) {
      return DateTime.now().difference(_lastLoginTime!);
    }
    return null;
  }

  /// Check if session is about to expire (within 1 day)
  bool get isSessionNearExpiry {
    if (_lastLoginTime != null) {
      final sessionAge = DateTime.now().difference(_lastLoginTime!);
      return sessionAge.inDays >= 6; // Warn when session has 1 day left
    }
    return false;
  }

  /// Refresh session timestamp
  Future<void> refreshSession() async {
    if (_isLoggedIn) {
      _lastLoginTime = DateTime.now();
      await _saveSessionToStorage();
      AppUtils.logInfo('Session refreshed');
    }
  }

  /// Get formatted session info for debugging
  Map<String, dynamic> getSessionInfo() {
    return {
      'isLoggedIn': _isLoggedIn,
      'userId': _userId,
      'userName': _userName,
      'sessionId': _sessionId,
      'lastLoginTime': _lastLoginTime?.toIso8601String(),
      'sessionDuration': sessionDuration?.inMinutes,
      'isNearExpiry': isSessionNearExpiry,
      'hasCookies': _sessionCookies != null && _sessionCookies!.isNotEmpty,
    };
  }
}