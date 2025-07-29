# Firebase Push Notification - Flutter Mobile App

A Flutter mobile application with complete Firebase push notification integration for Odoo systems.

## Features

- **Firebase Cloud Messaging (FCM)** integration
- **Auto token registration** when user logs in through WebView
- **Token refresh handling** with automatic updates
- **Local notifications** with custom actions
- **WebView integration** with Odoo login detection
- **Session management** with cookie extraction
- **API integration** with Odoo backend endpoints
- **Cross-platform support** (Android & iOS)

## Architecture

```
lib/
├── services/
│   ├── firebase_service.dart       # Firebase FCM management
│   ├── api_service.dart           # Odoo API communication
│   ├── notification_service.dart   # Local notifications
│   └── session_manager.dart       # Session & cookie management
├── models/
│   ├── token_response.dart        # API response models
│   └── notification_model.dart    # Notification data models
├── utils/
│   ├── constants.dart             # App constants
│   └── app_utils.dart            # Utility functions
├── ui/
│   └── webview_screen.dart       # Main WebView screen
└── main.dart                     # App entry point
```

## Setup

### 1. Dependencies

The app includes all necessary dependencies in `pubspec.yaml`:

- `firebase_core` & `firebase_messaging` - Firebase integration
- `flutter_local_notifications` - Local notifications
- `flutter_inappwebview` - WebView with advanced features
- `http` - API communication
- `shared_preferences` - Local storage
- `permission_handler` - Runtime permissions

### 2. Firebase Configuration

The app is already configured with Firebase using `firebase_options.dart`. Ensure you have:

- Valid Firebase project configuration
- FCM enabled in Firebase Console
- Proper Android/iOS app registration

### 3. Odoo Backend

The following API endpoints must be available in your Odoo instance:

- `POST /mobile/token/register` - Register Firebase token
- `POST /mobile/token/update` - Update Firebase token
- `GET /mobile/token/info` - Get token information

These endpoints are already implemented in the `firebase_push_notification` module.

## Usage

### Automatic Token Registration

1. User opens the app and navigates to Odoo WebView
2. When user logs in successfully, the app automatically:
   - Detects login completion
   - Extracts session cookies
   - Registers Firebase token with Odoo backend
   - Sets up push notification handling

### Push Notification Flow

1. **Token Generation**: Firebase automatically generates and manages tokens
2. **Registration**: Tokens are registered with Odoo when user logs in
3. **Updates**: Token refresh is handled automatically
4. **Notifications**: Incoming push notifications are displayed as local notifications
5. **Actions**: Notification taps navigate to specified URLs in WebView

### API Integration

The app communicates with Odoo using authenticated HTTP requests:

```dart
// Register token
final response = await apiService.registerToken(firebaseToken);

// Update token
final response = await apiService.updateToken(oldToken, newToken);

// Get token info
final response = await apiService.getTokenInfo();
```

### Session Management

Session cookies are automatically extracted and managed:

```dart
// Check login status
bool isLoggedIn = sessionManager.isLoggedIn;

// Get session info
Map<String, dynamic> info = sessionManager.getSessionInfo();

// Clear session
await sessionManager.clearSession();
```

## Configuration

### Constants

Update `lib/utils/constants.dart` for your Odoo configuration:

```dart
static const String baseUrl = "http://your-odoo-server.com";
static const String defaultWebViewUrl = "http://your-odoo-server.com/web";
```

### Permissions

**Android** - Already configured in `android/app/src/main/AndroidManifest.xml`:
- Internet access
- Network state access
- Notification permissions
- Storage permissions

**iOS** - Already configured in `ios/Runner/Info.plist`:
- Firebase App Delegate
- Push notifications capability
- Network security settings

## Error Handling

The app includes comprehensive error handling:

- Network connectivity checks
- API response validation
- Token format validation
- Session expiry handling
- Graceful error messages to users

## Logging

Debug logging is available throughout the app using `AppUtils`:

```dart
AppUtils.logInfo("Information message");
AppUtils.logWarning("Warning message"); 
AppUtils.logError("Error operation", error);
```

## Security

- Session cookies are securely stored locally
- API communications use HTTPS where possible
- Token validation and sanitization
- Automatic session cleanup on errors

## Testing

To test the implementation:

1. Build and install the app
2. Navigate to your Odoo instance
3. Log in through the WebView
4. Check logs for token registration confirmation
5. Send test push notification from Odoo backend
6. Verify notification receipt and tap actions

## Troubleshooting

**Token Registration Fails**:
- Check network connectivity
- Verify Odoo API endpoints are accessible
- Check session cookie extraction

**Notifications Not Received**:
- Verify Firebase configuration
- Check notification permissions
- Confirm FCM token is valid

**Login Detection Issues**:
- Verify URL patterns in login detection logic
- Check cookie extraction from WebView
- Ensure session manager initialization

## Contributing

When making changes:

1. Follow the existing code structure
2. Update constants and configurations as needed
3. Test both Android and iOS platforms
4. Ensure proper error handling
5. Update documentation

## License

This project is part of the Odoo Firebase Push Notification system.

