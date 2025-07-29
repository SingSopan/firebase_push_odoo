import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../utils/shared_preferences_helper.dart';

class NotificationScreen extends StatefulWidget {
  final RemoteMessage? initialMessage;
  final Function(String)? onNavigateToUrl;

  const NotificationScreen({
    super.key,
    this.initialMessage,
    this.onNavigateToUrl,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();
  
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _currentToken;
  Map<String, dynamic>? _tokenInfo;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadInitialData();
    
    if (widget.initialMessage != null) {
      _handleInitialNotification(widget.initialMessage!);
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Get current token
      _currentToken = _firebaseService.currentToken ?? SharedPreferencesHelper.getFirebaseToken();
      
      // Get token info from server
      _tokenInfo = await _firebaseService.getTokenInfoFromServer();
      
      // Load notifications (in a real app, this would come from a local database or server)
      await _loadNotifications();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    // In a real app, you would load notifications from local storage or server
    // For now, we'll show some sample data and the current notification if any
    _notifications = [
      if (widget.initialMessage != null) _convertMessageToNotification(widget.initialMessage!),
      // Add some sample notifications
      {
        'id': '1',
        'title': 'Welcome to Odoo',
        'body': 'Your account has been set up successfully',
        'data': {},
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        'read': false,
      },
      {
        'id': '2',
        'title': 'New Message',
        'body': 'You have a new message in your inbox',
        'data': {'link': '/mail/inbox'},
        'timestamp': DateTime.now().subtract(const Duration(hours: 3)),
        'read': true,
      },
    ];
  }

  Map<String, dynamic> _convertMessageToNotification(RemoteMessage message) {
    return {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? 'Notification',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'timestamp': DateTime.now(),
      'read': false,
    };
  }

  void _handleInitialNotification(RemoteMessage message) {
    // Handle the notification that launched the app
    debugPrint('Handling initial notification: ${message.messageId}');
    _notificationService.handleNotificationOpen(message);
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final url = data[Constants.notificationLinkKey]?.toString();
    
    if (url != null) {
      widget.onNavigateToUrl?.call(url);
      Navigator.pop(context); // Go back to WebView
    }
    
    // Mark as read
    setState(() {
      notification['read'] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showNotificationSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildTokenInfo(),
        Expanded(
          child: _buildNotificationsList(),
        ),
      ],
    );
  }

  Widget _buildTokenInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Firebase Token Info',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_currentToken != null)
            Text(
              'Token: ${_currentToken!.substring(0, 20)}...',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          if (_tokenInfo != null) ...[
            Text('User: ${_tokenInfo!['user_name'] ?? 'Unknown'}'),
            Text('User ID: ${_tokenInfo!['user_id'] ?? 'Unknown'}'),
            Text('Tokens Count: ${(_tokenInfo!['tokens'] as List?)?.length ?? 0}'),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _refreshToken,
                child: const Text('Refresh Token'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _testNotification,
                child: const Text('Test Notification'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return const Center(
        child: Text(
          'No notifications yet',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['read'] as bool? ?? false;
    final timestamp = notification['timestamp'] as DateTime;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRead ? Colors.grey : Colors.green,
          child: Icon(
            Icons.notifications,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification['title'] ?? 'Notification',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['body'] ?? ''),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _refreshToken() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final newToken = await _firebaseService.refreshToken();
      if (newToken != null) {
        _currentToken = newToken;
        _showSnackBar('Token refreshed successfully');
      } else {
        _showSnackBar('Failed to refresh token');
      }
      
      await _loadInitialData();
    } catch (e) {
      _showSnackBar('Error refreshing token: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _testNotification() {
    // Simulate a test notification
    final testNotification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': 'Test Notification',
      'body': 'This is a test notification from the app',
      'data': {'link': '/test'},
      'timestamp': DateTime.now(),
      'read': false,
    };
    
    setState(() {
      _notifications.insert(0, testNotification);
    });
    
    _showSnackBar('Test notification added');
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Firebase Token'),
              subtitle: Text(_currentToken?.substring(0, 30) ?? 'No token'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  if (_currentToken != null) {
                    // Copy to clipboard (would need clipboard package)
                    _showSnackBar('Token copied to clipboard');
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('User Session'),
              subtitle: Text(SharedPreferencesHelper.isLoggedIn() ? 'Logged in' : 'Not logged in'),
            ),
            ListTile(
              title: const Text('Clear Notifications'),
              trailing: IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  setState(() {
                    _notifications.clear();
                  });
                  Navigator.pop(context);
                  _showSnackBar('Notifications cleared');
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}