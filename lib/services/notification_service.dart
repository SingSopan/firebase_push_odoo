import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

typedef NotificationActionCallback = void Function(String? url, Map<String, dynamic> data);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  NotificationActionCallback? _onNotificationAction;
  NotificationActionCallback? _onForegroundNotification;

  // Initialize notification service
  void initialize({
    NotificationActionCallback? onNotificationAction,
    NotificationActionCallback? onForegroundNotification,
  }) {
    _onNotificationAction = onNotificationAction;
    _onForegroundNotification = onForegroundNotification;
    
    debugPrint('NotificationService initialized');
  }

  // Handle notification when app is in foreground
  void handleForegroundMessage(RemoteMessage message) {
    try {
      debugPrint('Handling foreground notification: ${message.messageId}');
      
      final title = message.notification?.title ?? 'New Notification';
      final body = message.notification?.body ?? '';
      final data = message.data;
      
      debugPrint('Notification title: $title');
      debugPrint('Notification body: $body');
      debugPrint('Notification data: $data');

      // Extract URL from notification data
      final url = _extractUrlFromData(data);
      
      // Show in-app notification or toast
      _showForegroundNotification(title, body, data);
      
      // Handle navigation if URL is provided
      if (url != null) {
        _onForegroundNotification?.call(url, data);
      }
    } catch (e) {
      debugPrint('Error handling foreground message: $e');
    }
  }

  // Handle notification when app is opened from background or terminated state
  void handleNotificationOpen(RemoteMessage message) {
    try {
      debugPrint('Handling notification open: ${message.messageId}');
      
      final data = message.data;
      final url = _extractUrlFromData(data);
      
      debugPrint('Opening notification with URL: $url');
      debugPrint('Notification data: $data');
      
      // Navigate to specific page based on notification data
      _onNotificationAction?.call(url, data);
    } catch (e) {
      debugPrint('Error handling notification open: $e');
    }
  }

  // Extract URL from notification data
  String? _extractUrlFromData(Map<String, dynamic> data) {
    // Check different possible keys for URL
    final possibleKeys = [
      Constants.notificationLinkKey,
      'url',
      'deep_link',
      'action_url',
      'redirect_url',
    ];
    
    for (String key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    
    return null;
  }

  // Show foreground notification (in-app)
  void _showForegroundNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) {
    // This would typically show a custom in-app notification
    // For now, we'll just log it
    debugPrint('=== FOREGROUND NOTIFICATION ===');
    debugPrint('Title: $title');
    debugPrint('Body: $body');
    debugPrint('Data: $data');
    debugPrint('================================');
  }

  // Get notification type from data
  String? getNotificationType(Map<String, dynamic> data) {
    return data[Constants.notificationTypeKey]?.toString();
  }

  // Get notification ID from data
  String? getNotificationId(Map<String, dynamic> data) {
    return data[Constants.notificationIdKey]?.toString();
  }

  // Check if notification should auto-navigate
  bool shouldAutoNavigate(Map<String, dynamic> data) {
    final type = getNotificationType(data);
    final url = _extractUrlFromData(data);
    
    // Auto-navigate for specific types or if URL is present
    return url != null && (
      type == 'auto_navigate' ||
      type == 'urgent' ||
      type == 'redirect'
    );
  }

  // Create notification data for testing
  static Map<String, dynamic> createTestNotificationData({
    String? url,
    String? type,
    String? notificationId,
    Map<String, dynamic>? additionalData,
  }) {
    final data = <String, dynamic>{};
    
    if (url != null) data[Constants.notificationLinkKey] = url;
    if (type != null) data[Constants.notificationTypeKey] = type;
    if (notificationId != null) data[Constants.notificationIdKey] = notificationId;
    
    if (additionalData != null) {
      data.addAll(additionalData);
    }
    
    return data;
  }

  // Create a test notification message
  static RemoteMessage createTestMessage({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? messageId,
  }) {
    // Note: RemoteMessage constructor is not directly accessible
    // This is a mock structure for testing purposes
    // In actual testing, you would use Firebase Test Lab or manual testing
    throw UnimplementedError('Use Firebase Test Lab or manual testing for RemoteMessage testing');
  }

  // Handle notification based on app state
  void handleNotificationByAppState(
    RemoteMessage message,
    AppState appState,
  ) {
    switch (appState) {
      case AppState.foreground:
        handleForegroundMessage(message);
        break;
      case AppState.background:
      case AppState.terminated:
        handleNotificationOpen(message);
        break;
    }
  }

  // Clear all callbacks
  void dispose() {
    _onNotificationAction = null;
    _onForegroundNotification = null;
    debugPrint('NotificationService disposed');
  }
}

// App state enum for better notification handling
enum AppState {
  foreground,
  background,
  terminated,
}

// Background message handler (top-level function required by Firebase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in your background handler,
  // such as Firestore, make sure to call `initializeApp` before using them.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint("Handling background message: ${message.messageId}");
  debugPrint("Background message data: ${message.data}");
  
  // Extract URL from data for potential local storage
  final notificationService = NotificationService();
  final url = notificationService._extractUrlFromData(message.data);
  
  if (url != null) {
    debugPrint("Background message contains URL: $url");
    // Store URL in SharedPreferences for when app resumes
    // This would require SharedPreferences initialization in background
    // For now, just log it
  }
  
  // Perform any background tasks here
  // Note: You cannot update UI from background handler
}