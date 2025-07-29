# Flutter Firebase Push Notification Integration

A comprehensive Flutter implementation for integrating Firebase push notifications with Odoo backend services. This app provides seamless push notification handling, automatic token registration upon user login, and robust WebView integration.

## Features

### 🔥 Firebase Integration
- **Automatic FCM token generation and management**
- **Token refresh handling with server synchronization**
- **Foreground, background, and terminated state notification handling**
- **Permission management for iOS and Android**

### 🌐 Odoo Backend Integration
- **Automatic token registration on user login detection**
- **REST API integration with retry mechanisms**
- **Support for existing Odoo endpoints:**
  - `POST /mobile/token/register` - Register new tokens
  - `POST /mobile/token/update` - Update existing tokens  
  - `GET /mobile/token/info` - Retrieve token information

### 📱 Smart WebView Features
- **Intelligent login detection via URL patterns and JavaScript**
- **Automatic token registration after successful login**
- **Network connectivity monitoring**
- **File download support**
- **Deep linking from notifications**

### 🔔 Notification Management
- **Complete notification history screen**
- **In-app notification display**
- **URL-based navigation from notifications**
- **Notification state management (read/unread)**

## Project Structure

```
lib/
├── services/
│   ├── firebase_service.dart       # FCM token management and messaging
│   ├── api_service.dart           # Odoo API integration with retry logic
│   └── notification_service.dart  # Notification handling for all app states
├── models/
│   ├── firebase_token_model.dart  # Data model for Firebase tokens
│   └── api_response_model.dart    # API response wrappers
├── utils/
│   ├── constants.dart             # App-wide constants and configuration
│   └── shared_preferences_helper.dart # Local storage management
├── widgets/
│   └── webview_widget.dart        # Enhanced WebView with login detection
├── screens/
│   └── notification_screen.dart   # Notification management UI
└── ui/
    └── webview_screen.dart        # Main WebView screen
```

## Setup Instructions

### 1. Firebase Configuration
1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/)
2. Add your Android and iOS apps to the Firebase project
3. Download the configuration files:
   - `google-services.json` for Android → `android/app/`
   - `GoogleService-Info.plist` for iOS → `ios/Runner/`

### 2. Dependencies
Run the following command to install all required dependencies:

```bash
flutter pub get
```

### 3. Platform Setup

#### Android Setup
Add the following to `android/app/build.gradle`:

```gradle
dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.0.0'
    // Other dependencies...
}
```

#### iOS Setup
Add the following to `ios/Runner/AppDelegate.swift`:

```swift
import Firebase
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 4. Configuration
Update the constants in `lib/utils/constants.dart`:

```dart
// Update with your Odoo server details
static const String odooBaseUrl = "YOUR_ODOO_SERVER_URL";
static const String odooDatabase = "YOUR_DATABASE_NAME";
static const String defaultWebViewUrl = "YOUR_WEBVIEW_URL";
```

## Usage

### Basic Integration

```dart
import 'package:webview_odoo_push/services/firebase_service.dart';
import 'package:webview_odoo_push/services/notification_service.dart';

// Initialize services
final firebaseService = FirebaseService();
final notificationService = NotificationService();

await firebaseService.initialize(
  onTokenUpdate: (token) => print('Token updated: $token'),
  onMessageReceived: (message) => notificationService.handleForegroundMessage(message),
  onMessageOpenedApp: (message) => notificationService.handleNotificationOpen(message),
);
```

### Token Registration

```dart
// Automatic registration after login detection
await firebaseService.handleUserLogin();

// Manual registration
final tokenModel = FirebaseTokenModel(
  token: 'fcm_token_here',
  os: 'android',
  userId: 123,
  userName: 'John Doe',
);

final response = await apiService.registerToken(tokenModel);
if (response.success) {
  print('Token registered successfully');
}
```

### Notification Handling

```dart
// Handle different notification scenarios
notificationService.initialize(
  onNotificationAction: (url, data) {
    // Navigate to specific page
    if (url != null) {
      webView.navigateToUrl(url);
    }
  },
  onForegroundNotification: (url, data) {
    // Show in-app notification
    showInAppNotification(data);
  },
);
```

## API Integration

The app integrates with the following Odoo endpoints:

### Register Token
```http
POST /mobile/token/register
Content-Type: application/json

{
  "token": "fcm_token",
  "os": "android",
  "user_id": 123,
  "user_name": "John Doe"
}
```

### Update Token
```http
POST /mobile/token/update
Content-Type: application/json

{
  "old_token": "old_fcm_token",
  "new_token": "new_fcm_token",
  "os": "android"
}
```

### Get Token Info
```http
GET /mobile/token/info
```

## Testing

Run the included tests:

```bash
flutter test
```

The test suite covers:
- Model serialization/deserialization
- API response handling
- Token management logic

## Troubleshooting

### Common Issues

1. **Token not registering**: Ensure user is logged in and network is available
2. **Notifications not appearing**: Check Firebase configuration and permissions
3. **Login detection failing**: Verify URL patterns in `constants.dart`

### Debug Mode

Enable debug logging by setting:

```dart
debugPrint('Debug message here');
```

### Firebase Token Testing

Use the notification screen to:
- View current FCM token
- Test token refresh
- Manually trigger notifications

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Check the [Issues](https://github.com/SingSopan/firebase_push_odoo/issues) page
- Review the Odoo integration documentation
- Test with Firebase Test Lab for comprehensive device testing
