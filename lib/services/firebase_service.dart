import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/firebase_token_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/shared_preferences_helper.dart';

typedef TokenUpdateCallback = void Function(String newToken);
typedef NotificationCallback = void Function(RemoteMessage message);

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  
  TokenUpdateCallback? _onTokenUpdate;
  NotificationCallback? _onMessageReceived;
  NotificationCallback? _onMessageOpenedApp;

  String? _currentToken;
  bool _isInitialized = false;

  // Getters
  String? get currentToken => _currentToken;
  bool get isInitialized => _isInitialized;

  // Initialize Firebase Messaging
  Future<void> initialize({
    TokenUpdateCallback? onTokenUpdate,
    NotificationCallback? onMessageReceived,
    NotificationCallback? onMessageOpenedApp,
  }) async {
    if (_isInitialized) return;

    try {
      _onTokenUpdate = onTokenUpdate;
      _onMessageReceived = onMessageReceived;
      _onMessageOpenedApp = onMessageOpenedApp;

      // Initialize SharedPreferences
      await SharedPreferencesHelper.init();

      // Request permissions
      await _requestPermissions();

      // Get and handle initial token
      await _initializeToken();

      // Set up token refresh listener
      _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);

      // Set up message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      debugPrint('FirebaseService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize FirebaseService: $e');
      rethrow;
    }
  }

  // Request notification permissions
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
    return settings;
  }

  // Initialize FCM token
  Future<void> _initializeToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        await SharedPreferencesHelper.saveFirebaseToken(token);
        debugPrint('FCM Token obtained: ${token.substring(0, 20)}...');
        
        // Save device OS
        await SharedPreferencesHelper.saveDeviceOS(_getDeviceOS());
        
        // Notify callback
        _onTokenUpdate?.call(token);
      }
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  // Handle token refresh
  Future<void> _handleTokenRefresh(String newToken) async {
    try {
      final oldToken = _currentToken;
      _currentToken = newToken;
      
      await SharedPreferencesHelper.saveFirebaseToken(newToken);
      debugPrint('FCM Token refreshed: ${newToken.substring(0, 20)}...');

      // Update token on server if user is logged in
      if (SharedPreferencesHelper.isLoggedIn() && oldToken != null) {
        await updateTokenOnServer(oldToken, newToken);
      }

      // Notify callback
      _onTokenUpdate?.call(newToken);
    } catch (e) {
      debugPrint('Failed to handle token refresh: $e');
    }
  }

  // Set up message handlers
  void _setupMessageHandlers() {
    // Handle initial message when app is launched from terminated state
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App launched from terminated state with message: ${message.messageId}');
        _onMessageOpenedApp?.call(message);
      }
    });

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');
      debugPrint('Message data: ${message.data}');
      
      if (message.notification != null) {
        debugPrint('Message notification: ${message.notification!.title}');
      }

      _onMessageReceived?.call(message);
    });

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background with message: ${message.messageId}');
      _onMessageOpenedApp?.call(message);
    });
  }

  // Register token with Odoo server
  Future<bool> registerTokenWithServer() async {
    try {
      if (_currentToken == null) {
        debugPrint('No FCM token available for registration');
        return false;
      }

      final tokenModel = FirebaseTokenModel(
        token: _currentToken!,
        os: _getDeviceOS(),
        userId: SharedPreferencesHelper.getUserId(),
        userName: SharedPreferencesHelper.getUserName(),
        dateRegistered: DateTime.now(),
      );

      final response = await _apiService.registerToken(tokenModel);
      
      if (response.success) {
        debugPrint('Token registered successfully: ${response.message}');
        
        // Save user session if provided
        if (response.data?.userId != null && response.data?.userName != null) {
          await SharedPreferencesHelper.saveUserSession(
            userId: response.data!.userId!,
            userName: response.data!.userName!,
          );
        }
        
        // Save complete token model
        await SharedPreferencesHelper.saveTokenModel(tokenModel.copyWith(
          userId: response.data?.userId,
          userName: response.data?.userName,
        ));
        
        return true;
      } else {
        debugPrint('Failed to register token: ${response.message}');
        return false;
      }
    } catch (e) {
      debugPrint('Error registering token with server: $e');
      return false;
    }
  }

  // Update token on server
  Future<bool> updateTokenOnServer(String oldToken, String newToken) async {
    try {
      final response = await _apiService.updateToken(
        oldToken,
        newToken,
        os: _getDeviceOS(),
      );

      if (response.success) {
        debugPrint('Token updated successfully: ${response.message}');
        return true;
      } else {
        debugPrint('Failed to update token: ${response.message}');
        return false;
      }
    } catch (e) {
      debugPrint('Error updating token on server: $e');
      return false;
    }
  }

  // Get token info from server
  Future<Map<String, dynamic>?> getTokenInfoFromServer() async {
    try {
      final response = await _apiService.getTokenInfo();
      
      if (response.success && response.data != null) {
        debugPrint('Token info retrieved successfully');
        return response.data!.toJson();
      } else {
        debugPrint('Failed to get token info: ${response.message}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting token info from server: $e');
      return null;
    }
  }

  // Force token refresh
  Future<String?> refreshToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      final newToken = await _firebaseMessaging.getToken();
      
      if (newToken != null) {
        await _handleTokenRefresh(newToken);
        return newToken;
      }
      
      return null;
    } catch (e) {
      debugPrint('Failed to refresh token: $e');
      return null;
    }
  }

  // Check if token needs to be refreshed
  bool shouldRefreshToken() {
    return SharedPreferencesHelper.shouldRefreshToken();
  }

  // Auto-refresh token if needed
  Future<void> autoRefreshTokenIfNeeded() async {
    if (shouldRefreshToken()) {
      debugPrint('Token needs refresh, refreshing...');
      await refreshToken();
    }
  }

  // Handle user login (call after successful login detection)
  Future<void> handleUserLogin() async {
    try {
      debugPrint('Handling user login, registering token...');
      final success = await registerTokenWithServer();
      
      if (!success) {
        // Fallback to XML-RPC if needed
        if (_currentToken != null) {
          await _apiService.sendTokenViaXmlRpc(_currentToken!);
        }
      }
    } catch (e) {
      debugPrint('Error handling user login: $e');
    }
  }

  // Handle user logout
  Future<void> handleUserLogout() async {
    try {
      debugPrint('Handling user logout, clearing session...');
      await SharedPreferencesHelper.clearUserSession();
    } catch (e) {
      debugPrint('Error handling user logout: $e');
    }
  }

  // Get device OS
  String _getDeviceOS() {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else {
      return 'unknown';
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Failed to subscribe to topic $topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Failed to unsubscribe from topic $topic: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _apiService.dispose();
    _onTokenUpdate = null;
    _onMessageReceived = null;
    _onMessageOpenedApp = null;
  }
}