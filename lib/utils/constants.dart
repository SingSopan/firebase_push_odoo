class Constants {
  // API Configuration
  static const String odooBaseUrl = "https://dev.pstlgroup.com";
  static const String odooDatabase = "dev";
  static const String odooUsername = "admin";
  static const String odooPassword = "pramisti";
  
  // Alternative URL configuration for different environments
  static const String defaultWebViewUrl = "http://194.59.165.228:8079/web?db=16Notification";
  
  // API Endpoints
  static const String tokenRegisterEndpoint = "/mobile/token/register";
  static const String tokenUpdateEndpoint = "/mobile/token/update";
  static const String tokenInfoEndpoint = "/mobile/token/info";
  static const String xmlRpcEndpoint = "/xmlrpc/2/object";
  
  // HTTP Headers
  static const Map<String, String> defaultHeaders = {
    "Content-Type": "application/json",
    "X-Access-Type": "webview",
  };
  
  static const Map<String, String> xmlRpcHeaders = {
    "Content-Type": "text/xml",
    "X-Access-Type": "webview",
  };
  
  // SharedPreferences Keys
  static const String keyFirebaseToken = "firebase_token";
  static const String keyUserSession = "user_session";
  static const String keyUserId = "user_id";
  static const String keyUserName = "user_name";
  static const String keyIsLoggedIn = "is_logged_in";
  static const String keyLastTokenUpdate = "last_token_update";
  static const String keyDeviceOS = "device_os";
  
  // Notification Configuration
  static const String notificationChannelId = "firebase_push_channel";
  static const String notificationChannelName = "Firebase Push Notifications";
  static const String notificationChannelDescription = "Notifications from Odoo server";
  
  // Retry Configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Login Detection
  static const List<String> loginSuccessIndicators = [
    '/web/login',
    '/web/home',
    '/web/dashboard',
    'odoo_session_id',
  ];
  
  static const List<String> logoutIndicators = [
    '/web/login?message=',
    '/web/database/selector',
    'login_required',
  ];
  
  // Device OS Detection
  static String get deviceOS {
    // This would typically use Platform.isAndroid/Platform.isIOS
    // For now, defaulting to android since the current implementation assumes it
    return 'android';
  }
  
  // Notification data keys
  static const String notificationLinkKey = "link";
  static const String notificationTypeKey = "type";
  static const String notificationIdKey = "notification_id";
}