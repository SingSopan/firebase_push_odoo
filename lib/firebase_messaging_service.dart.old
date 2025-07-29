import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // For showSnackBar, though often handled globally.

typedef UrlUpdateCallback = void Function(String url);

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final UrlUpdateCallback _onUrlUpdate;

  FirebaseMessagingService(this._onUrlUpdate); // Constructor to receive the callback

  Future<void> initializeFirebaseMessaging() async {
    // Request permission for notifications (iOS & Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications.');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission for notifications.');
    } else {
      print('User declined or has not accepted permission for notifications.');
      // You might want to inform the user that notifications won't be shown.
    }

    // Get FCM token and send to server
    _firebaseMessaging.getToken().then((token) {
      if (token != null) {
        print("FCM Token: $token");
        _sendTokenToOdooServer(token); // Send token to your Odoo server
      }
    });

    // Handle initial message when the app is launched from a terminated state
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && message.data['link'] != null) { // Assuming 'link' is the key for URL in notification data
        print('App launched from terminated state with notification: ${message.data}');
        _onUrlUpdate(message.data['link']); // Call the callback to update WebView URL
      }
    });

    // Handle messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
      // You can display a local notification here if needed
      // For a toast, you would typically need a BuildContext or a global key.
      // For simplicity, we'll just print or use a global messenger key.
      if (message.notification?.title != null) {
        // You might use a SnackBar here, requiring a BuildContext from somewhere,
        // or a global ScaffoldMessengerKey in main.dart to show toasts from anywhere.
        // For now, let's just print.
        print("New Notification: ${message.notification?.title}");
      }

      // If foreground notification should also update URL
      if (message.data['link'] != null) {
        _onUrlUpdate(message.data['link']); // Update WebView if data contains a link
      }
    });

    // Handle messages when the app is opened from a background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      if (message.data['link'] != null) { // Assuming 'link' is the key for URL in notification data
        print('App opened from background with notification: ${message.data}');
        _onUrlUpdate(message.data['link']); // Call the callback to update WebView URL
      }
    });

    // You can also handle background messages using a top-level function
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Placeholder for sending FCM token to Odoo server via XML-RPC
  // In a real application, you would use an XML-RPC library or Odoo's REST API if available.
  void _sendTokenToOdooServer(String token) async {
    final String urlApi = "https://dev.pstlgroup.com"; //
    final String dbApi = "dev"; //
    final String usernameApi = "admin"; //
    final String passwordApi = "pramisti"; //

    try {
      // Simulate XML-RPC authentication and token creation.
      // In a real scenario, this would involve crafting an XML payload
      // and sending it via HTTP POST.
      final String payload = '''
        <?xml version="1.0"?>
        <methodCall>
            <methodName>call</methodName>
            <params>
                <param><value><string>$dbApi</string></value></param>
                <param><value><int>1</int></value></param> <param><value><string>$passwordApi</string></value></param>
                <param><value><string>push.notification.token</string></value></param>
                <param><value><string>create</string></value></param>
                <param><value><array><data><value><struct>
                    <member><name>token</name><value><string>$token</string></value></member>
                    <member><name>date</name><value><string>${DateTime.now().toIso8601String()}</string></value></member>
                </struct></value></data></array></value></param>
            </params>
        </methodCall>
      ''';

      final response = await http.post(
        Uri.parse("$urlApi/xmlrpc/2/object"),
        headers: {
          "Content-Type": "text/xml",
          "X-Access-Type": "webview",
        },
        body: payload,
      );

      if (response.statusCode == 200) {
        print("Token sent to Odoo server successfully (simulated)");
      } else {
        print("Failed to send token. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error sending token to Odoo server: $e");
    }
  }
}

// This is a top-level function for handling background messages.
// It must not be an anonymous function.
// It must not be a class method.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in your background handler,
  // such as Firestore, make sure to call `initializeApp` before using them.
  // await Firebase.initializeApp(); // Only if needed here.

  print("Handling a background message: ${message.messageId}");
  if (message.data['link'] != null) {
    print("Background message contains link: ${message.data['link']}");
    // You cannot directly update UI from a background handler.
    // You would typically store this link locally (e.g., SharedPreferences)
    // and then read it when the app resumes/starts.
  }
  // This is where you would perform long-running tasks, similar to MyWorker in Java
  // For example, fetching data, processing, or saving to local storage.
}