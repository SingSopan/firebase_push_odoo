import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_odoo_push/models/notification_model.dart';
import 'package:webview_odoo_push/utils/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Function(String)? _onNotificationTap;
  bool _isInitialized = false;

  /// Initialize local notifications
  Future<void> initialize({Function(String)? onNotificationTap}) async {
    if (_isInitialized) return;

    _onNotificationTap = onNotificationTap;

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    await _createNotificationChannel();
    await requestPermissions();

    _isInitialized = true;

    if (kDebugMode) {
      print('Notification Service: Initialized successfully');
    }
  }

  /// Handle notification tap
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty && _onNotificationTap != null) {
      _onNotificationTap!(payload);
    }
    if (kDebugMode) {
      print('Notification tapped with payload: $payload');
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        Constants.notificationChannelId,
        Constants.notificationChannelName,
        description: Constants.notificationChannelDescription,
        importance: Importance.high,
        enableLights: true,
        enableVibration: true,
        showBadge: true,
        playSound: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13 and above
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        if (status.isDenied) {
          if (kDebugMode) {
            print('Notification permission denied');
          }
          return false;
        }
      }
    }

    if (Platform.isIOS) {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }

    return true;
  }

  /// Show local notification
  Future<void> showNotification(NotificationModel notification) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      Constants.notificationChannelId,
      Constants.notificationChannelName,
      channelDescription: Constants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableLights: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    final id = notification.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    final payload = notification.hasValidLink ? notification.link : null;

    await _flutterLocalNotificationsPlugin.show(
      id,
      notification.title ?? 'Odoo Notification',
      notification.body ?? 'You have a new notification',
      notificationDetails,
      payload: payload,
    );

    if (kDebugMode) {
      print('Local notification shown: ${notification.title}');
    }
  }

  /// Show notification with custom action buttons (Android only)
  Future<void> showNotificationWithActions(
    NotificationModel notification, {
    List<AndroidNotificationAction>? actions,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      Constants.notificationChannelId,
      Constants.notificationChannelName,
      channelDescription: Constants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableLights: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      actions: actions,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    final id = notification.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    final payload = notification.hasValidLink ? notification.link : null;

    await _flutterLocalNotificationsPlugin.show(
      id,
      notification.title ?? 'Odoo Notification',
      notification.body ?? 'You have a new notification',
      notificationDetails,
      payload: payload,
    );

    if (kDebugMode) {
      print('Local notification with actions shown: ${notification.title}');
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    } else if (Platform.isIOS) {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return result?.isEnabled ?? false;
    }
    return false;
  }

  /// Open app settings for notification permissions
  Future<void> openNotificationSettings() async {
    if (Platform.isAndroid) {
      await openAppSettings();
    }
  }

  /// Show a simple text notification
  Future<void> showSimpleNotification(String title, String body, {String? payload}) async {
    final notification = NotificationModel(
      title: title,
      body: body,
      link: payload,
    );
    await showNotification(notification);
  }

  /// Set notification tap callback
  void setOnNotificationTap(Function(String) callback) {
    _onNotificationTap = callback;
  }
}