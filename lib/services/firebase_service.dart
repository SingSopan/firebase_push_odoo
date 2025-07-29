import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_odoo_push/models/notification_model.dart';
import 'package:webview_odoo_push/models/token_response.dart';
import 'package:webview_odoo_push/services/api_service.dart';
import 'package:webview_odoo_push/services/notification_service.dart';
import 'package:webview_odoo_push/utils/constants.dart';

typedef UrlUpdateCallback = void Function(String url);
typedef NotificationCallback = void Function(NotificationModel notification);

/// Enhanced Firebase service with proper API integration
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  UrlUpdateCallback? _onUrlUpdate;
  NotificationCallback? _onNotificationReceived;
  String? _currentToken;
  bool _isInitialized = false;

  /// Initialize Firebase messaging with all required callbacks
  Future<void> initialize({
    UrlUpdateCallback? onUrlUpdate,
    NotificationCallback? onNotificationReceived,
  }) async {
    if (_isInitialized) return;

    _onUrlUpdate = onUrlUpdate;
    _onNotificationReceived = onNotificationReceived;

    try {
      // Initialize notification service first
      await _notificationService.initialize(
        onNotificationTap: _handleNotificationTap,
      );

      // Load API session cookies
      await _apiService.loadSessionCookies();

      // Request notification permissions
      await _requestNotificationPermissions();

      // Get and handle initial Firebase token
      await _handleInitialToken();

      // Set up token refresh listener
      _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);

      // Handle initial message (app launched from terminated state)
      await _handleInitialMessage();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      _isInitialized = true;

      if (kDebugMode) {
        print('Firebase Service: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase Service: $e');
      }
      rethrow;
    }
  }

  /// Request notification permissions
  Future<void> _requestNotificationPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('Notification permission status: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) {
          print('User denied notification permissions');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting notification permissions: $e');
      }
    }
  }

  /// Handle initial Firebase token
  Future<void> _handleInitialToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _saveTokenLocally(token);
        
        if (kDebugMode) {
          print('Firebase token obtained: $token');
        }

        // Register token with Odoo if user is logged in
        if (await _apiService.isUserLoggedIn()) {
          await registerTokenWithOdoo(token);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling initial token: $e');
      }
    }
  }

  /// Handle token refresh
  Future<void> _handleTokenRefresh(String newToken) async {
    try {
      if (kDebugMode) {
        print('Firebase token refreshed: $newToken');
      }

      final oldToken = _currentToken;
      _currentToken = newToken;
      await _saveTokenLocally(newToken);

      // Update token with Odoo if user is logged in
      if (await _apiService.isUserLoggedIn() && oldToken != null) {
        await updateTokenWithOdoo(oldToken, newToken);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling token refresh: $e');
      }
    }
  }

  /// Handle initial message when app is launched from terminated state
  Future<void> _handleInitialMessage() async {
    try {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        final notification = _createNotificationModel(initialMessage);
        _handleNotificationAction(notification);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling initial message: $e');
      }
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      if (kDebugMode) {
        print('Foreground message received: ${message.data}');
      }

      final notification = _createNotificationModel(message);
      
      // Show local notification
      await _notificationService.showNotification(notification);
      
      // Notify callback
      _onNotificationReceived?.call(notification);

    } catch (e) {
      if (kDebugMode) {
        print('Error handling foreground message: $e');
      }
    }
  }

  /// Handle background message tap
  Future<void> _handleBackgroundMessageTap(RemoteMessage message) async {
    try {
      if (kDebugMode) {
        print('Background message tapped: ${message.data}');
      }

      final notification = _createNotificationModel(message);
      _handleNotificationAction(notification);
    } catch (e) {
      if (kDebugMode) {
        print('Error handling background message tap: $e');
      }
    }
  }

  /// Handle notification tap from local notifications
  void _handleNotificationTap(String payload) {
    if (payload.isNotEmpty && _onUrlUpdate != null) {
      if (kDebugMode) {
        print('Local notification tapped with payload: $payload');
      }
      _onUrlUpdate!(payload);
    }
  }

  /// Handle notification actions (URL navigation)
  void _handleNotificationAction(NotificationModel notification) {
    if (notification.hasValidLink && _onUrlUpdate != null) {
      _onUrlUpdate!(notification.link!);
    }
    _onNotificationReceived?.call(notification);
  }

  /// Create notification model from Firebase message
  NotificationModel _createNotificationModel(RemoteMessage message) {
    return NotificationModel(
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
      link: message.data['link'],
      messageId: message.messageId,
      receivedAt: DateTime.now(),
    );
  }

  /// Register Firebase token with Odoo server
  Future<TokenResponse> registerTokenWithOdoo(String token) async {
    try {
      if (kDebugMode) {
        print('Registering token with Odoo: $token');
      }

      final response = await _apiService.registerToken(token);
      
      if (response.isSuccess) {
        if (kDebugMode) {
          print('Token registered successfully with Odoo');
        }
      } else {
        if (kDebugMode) {
          print('Failed to register token: ${response.message}');
        }
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error registering token with Odoo: $e');
      }
      return TokenResponse(
        status: 'error',
        message: 'Error registering token: $e',
      );
    }
  }

  /// Update Firebase token with Odoo server
  Future<TokenResponse> updateTokenWithOdoo(String oldToken, String newToken) async {
    try {
      if (kDebugMode) {
        print('Updating token with Odoo: $oldToken -> $newToken');
      }

      final response = await _apiService.updateToken(oldToken, newToken);
      
      if (response.isSuccess) {
        if (kDebugMode) {
          print('Token updated successfully with Odoo');
        }
      } else {
        if (kDebugMode) {
          print('Failed to update token: ${response.message}');
        }
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating token with Odoo: $e');
      }
      return TokenResponse(
        status: 'error',
        message: 'Error updating token: $e',
      );
    }
  }

  /// Get current Firebase token
  Future<String?> getCurrentToken() async {
    try {
      if (_currentToken != null) {
        return _currentToken;
      }
      return await _firebaseMessaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current token: $e');
      }
      return null;
    }
  }

  /// Save token to local storage
  Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(Constants.keyFirebaseToken, token);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving token locally: $e');
      }
    }
  }

  /// Get token from local storage
  Future<String?> getTokenFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(Constants.keyFirebaseToken);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting token from storage: $e');
      }
      return null;
    }
  }

  /// Auto-register token after user login
  Future<TokenResponse?> autoRegisterAfterLogin() async {
    try {
      final token = await getCurrentToken();
      if (token != null && await _apiService.isUserLoggedIn()) {
        return await registerTokenWithOdoo(token);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error in auto-register after login: $e');
      }
      return null;
    }
  }

  /// Set URL update callback
  void setUrlUpdateCallback(UrlUpdateCallback callback) {
    _onUrlUpdate = callback;
  }

  /// Set notification received callback
  void setNotificationCallback(NotificationCallback callback) {
    _onNotificationReceived = callback;
  }

  /// Check if Firebase is available on the platform
  bool isFirebaseAvailable() {
    return Platform.isAndroid || Platform.isIOS;
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (kDebugMode) {
      print('Background message received: ${message.messageId}');
      print('Message data: ${message.data}');
    }

    // You can handle background processing here
    // Note: You cannot directly update UI from background handler
    // You would typically save data to local storage to be processed when app resumes
    
  } catch (e) {
    if (kDebugMode) {
      print('Error in background message handler: $e');
    }
  }
}