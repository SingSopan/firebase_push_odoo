import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_odoo_push/utils/constants.dart';
import 'package:flutter/foundation.dart';

class AppUtils {
  static final AppUtils _instance = AppUtils._internal();
  factory AppUtils() => _instance;
  AppUtils._internal();

  /// Check internet connectivity
  static Future<bool> isConnectedToInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking connectivity: $e');
      }
      return false;
    }
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Get platform-specific user agent
  static String getUserAgent() {
    if (Platform.isAndroid) {
      return 'Odoo-Mobile-App-Android/1.0';
    } else if (Platform.isIOS) {
      return 'Odoo-Mobile-App-iOS/1.0';
    } else {
      return 'Odoo-Mobile-App/1.0';
    }
  }

  /// Extract domain from URL
  static String? extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }

  /// Save app state to local storage
  static Future<void> saveAppState(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving app state: $e');
      }
    }
  }

  /// Get app state from local storage
  static Future<T?> getAppState<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.get(key) as T?;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting app state: $e');
      }
      return null;
    }
  }

  /// Clear all app data
  static Future<void> clearAllAppData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (kDebugMode) {
        print('All app data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing app data: $e');
      }
    }
  }

  /// Format timestamp for display
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Generate unique ID
  static String generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Validate Firebase token format
  static bool isValidFirebaseToken(String token) {
    // Basic validation for Firebase token format
    return token.isNotEmpty && 
           token.length > 50 && 
           token.contains(':') &&
           !token.contains(' ');
  }

  /// Check if app is running in debug mode
  static bool isDebugMode() {
    return kDebugMode;
  }

  /// Sanitize URL for WebView
  static String sanitizeUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }

  /// Extract session ID from cookies
  static String? extractSessionId(String cookies) {
    try {
      final cookieList = cookies.split(';');
      for (String cookie in cookieList) {
        final parts = cookie.trim().split('=');
        if (parts.length == 2 && parts[0].trim() == 'session_id') {
          return parts[1].trim();
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting session ID: $e');
      }
      return null;
    }
  }

  /// Create error log entry
  static void logError(String operation, dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('ERROR in $operation: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Create info log entry
  static void logInfo(String message) {
    if (kDebugMode) {
      print('INFO: $message');
    }
  }

  /// Create warning log entry
  static void logWarning(String message) {
    if (kDebugMode) {
      print('WARNING: $message');
    }
  }
}