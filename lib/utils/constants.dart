import 'dart:io';

class Constants {
  // API Configuration
  static const String baseUrl = "http://194.59.165.228:8079";
  static const String registerTokenEndpoint = "/mobile/token/register";
  static const String updateTokenEndpoint = "/mobile/token/update";
  static const String tokenInfoEndpoint = "/mobile/token/info";
  
  // Default URL for WebView
  static const String defaultWebViewUrl = "http://194.59.165.228:8079/web?db=16Notification";
  
  // SharedPreferences Keys
  static const String keyFirebaseToken = "firebase_token";
  static const String keyUserLoggedIn = "user_logged_in";
  static const String keySessionCookies = "session_cookies";
  static const String keyUserId = "user_id";
  static const String keyUserName = "user_name";
  static const String keyLastTokenUpdate = "last_token_update";
  
  // Notification Channels
  static const String notificationChannelId = "odoo_notifications";
  static const String notificationChannelName = "Odoo Notifications";
  static const String notificationChannelDescription = "Notifications from Odoo system";
  
  // Platform Detection
  static String get currentPlatform {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else {
      return 'unknown';
    }
  }
  
  // Headers for API requests
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'X-Access-Type': 'webview',
    'Accept': 'application/json',
  };
  
  // Error Messages
  static const String errorNoInternet = "No internet connection";
  static const String errorTokenRegistration = "Failed to register Firebase token";
  static const String errorTokenUpdate = "Failed to update Firebase token";
  static const String errorGetTokenInfo = "Failed to get token information";
  static const String errorNotificationPermission = "Notification permission denied";
  static const String errorInvalidResponse = "Invalid response from server";
  
  // Success Messages
  static const String successTokenRegistered = "Token registered successfully";
  static const String successTokenUpdated = "Token updated successfully";
  
  // Login Detection
  static const String loginSuccessUrl = "/web/login";
  static const String loginPageUrl = "/web/login";
  static const String dashboardUrl = "/web";
  
  // Timeout Configuration
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);
}