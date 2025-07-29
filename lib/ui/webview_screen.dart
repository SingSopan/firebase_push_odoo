import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../widgets/webview_widget.dart';
import '../screens/notification_screen.dart';
import '../utils/constants.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  String currentUrl = Constants.defaultWebViewUrl;
  DateTime? lastBackPressedTime;
  
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late WebViewWidget _webViewWidget;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _requestPermissions();
    _listenForNetworkChanges();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize Firebase service
      await _firebaseService.initialize(
        onTokenUpdate: _handleTokenUpdate,
        onMessageReceived: _handleForegroundMessage,
        onMessageOpenedApp: _handleNotificationOpen,
      );

      // Initialize Notification service
      _notificationService.initialize(
        onNotificationAction: _handleNotificationAction,
        onForegroundNotification: _handleForegroundNotification,
      );

      debugPrint('Services initialized successfully');
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  void _handleTokenUpdate(String newToken) {
    debugPrint('Token updated: ${newToken.substring(0, 20)}...');
    _showToast('Firebase token updated');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _notificationService.handleForegroundMessage(message);
  }

  void _handleNotificationOpen(RemoteMessage message) {
    _notificationService.handleNotificationOpen(message);
  }

  void _handleNotificationAction(String? url, Map<String, dynamic> data) {
    if (url != null) {
      _navigateToUrl(url);
      _showToast('Navigating from notification: $url');
    }
  }

  void _handleForegroundNotification(String? url, Map<String, dynamic> data) {
    if (url != null) {
      _navigateToUrl(url);
    }
    
    // Show in-app notification
    _showNotificationBanner(data);
  }

  void _showNotificationBanner(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? 'New Notification';
    final body = data['body']?.toString() ?? '';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            final url = data[Constants.notificationLinkKey]?.toString();
            if (url != null) {
              _navigateToUrl(url);
            }
          },
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isDenied) {
        _showToast("Storage permission denied. Cannot download files.");
      }
    }
  }

  void _listenForNetworkChanges() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      ConnectivityResult result = results.first;

      if (result == ConnectivityResult.none) {
        _showToast("Network is Offline");
        _showNetworkErrorDialog();
      } else {
        if (currentUrl.contains('error.html') || currentUrl.isEmpty || currentUrl == 'about:blank') {
          _navigateToUrl(Constants.defaultWebViewUrl);
        }
      }
    });
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Error"),
          content: const Text("No internet connection was found!"),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToUrl(String url) {
    setState(() {
      currentUrl = url;
    });
    _webViewWidget.navigateToUrl(url);
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openNotificationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationScreen(
          onNavigateToUrl: _navigateToUrl,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firebaseService.dispose();
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _webViewWidget = WebViewWidget(
      initialUrl: currentUrl,
      onUrlChanged: (url) {
        setState(() {
          currentUrl = url;
        });
      },
      onLoginDetected: (url) {
        debugPrint('Login detected in WebView: $url');
      },
      onLogoutDetected: () {
        debugPrint('Logout detected in WebView');
      },
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (await _webViewWidget.goBack()) {
          return;
        } else {
          final now = DateTime.now();
          if (lastBackPressedTime == null || now.difference(lastBackPressedTime!) > const Duration(seconds: 2)) {
            lastBackPressedTime = now;
            _showToast("Press once again to exit!");
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Odoo App'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewWidget.reload(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: _openNotificationScreen,
            ),
            PopupMenuButton<String>(
              onSelected: _handleMenuSelection,
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'home',
                    child: Text('Home'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'refresh_token',
                    child: Text('Refresh Token'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'notifications',
                    child: Text('Notifications'),
                  ),
                ];
              },
            ),
          ],
        ),
        body: SafeArea(
          child: _webViewWidget,
        ),
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'home':
        _navigateToUrl(Constants.defaultWebViewUrl);
        break;
      case 'refresh_token':
        _refreshFirebaseToken();
        break;
      case 'notifications':
        _openNotificationScreen();
        break;
    }
  }

  Future<void> _refreshFirebaseToken() async {
    try {
      _showToast('Refreshing Firebase token...');
      final newToken = await _firebaseService.refreshToken();
      if (newToken != null) {
        _showToast('Token refreshed successfully');
      } else {
        _showToast('Failed to refresh token');
      }
    } catch (e) {
      _showToast('Error refreshing token: $e');
    }
  }
}

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isDenied) {
        _showToast("Storage permission denied. Cannot download files.");
      }
    }
  }

  // void _initDynamicLinks() {
  //   FirebaseDynamicLinks.instance.onLink.listen(
  //         (PendingDynamicLinkData? dynamicLink) {
  //       final Uri? deepLink = dynamicLink?.link;
  //       if (deepLink != null) {
  //         print('Dynamic Link received: $deepLink');
  //         _updateUrlFromNotification(deepLink.toString());
  //       }
  //     },
  //   ).onError((error) {
  //     print('onLink error');
  //     print(error.message);
  //   });
  //
  //   FirebaseDynamicLinks.instance.getInitialLink().then(
  //         (PendingDynamicLinkData? dynamicLink) {
  //       final Uri? deepLink = dynamicLink?.link;
  //       if (deepLink != null) {
  //         print('Initial Dynamic Link: $deepLink');
  //         if (currentUrl == "https://dev.pstlgroup.com" || !currentUrl.contains("http")) {
  //           _updateUrlFromNotification(deepLink.toString());
  //         }
  //       }
  //     },
  //   );
  // }

  void _listenForNetworkChanges() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      ConnectivityResult result = results.first;

      if (result == ConnectivityResult.none) {
        _showToast("Network is Offline");
        webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri('file:///android_asset/flutter_assets/assets/www/error.html')));
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("Error"),
              content: const Text("No internet connection was found!"),
              actions: <Widget>[
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        if (currentUrl.contains('error.html') || currentUrl.isEmpty || currentUrl == 'about:blank') {
          webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(defaultUrl)));
        }
      }
    });
  }

  void _setupDownloadListener() {
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    print('Download task ($id) is in status ($status) and progress ($progress)');
  }

  Future<void> _handleDownload(String url, String userAgent, String contentDisposition, String mimeType) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final savedDir = externalDir.path;
        final fileName = Uri.decodeComponent(contentDisposition.split('filename=').last.replaceAll('"', ''));
        final taskId = await FlutterDownloader.enqueue(
          url: url,
          savedDir: savedDir,
          fileName: fileName,
          showNotification: true,
          openFileFromNotification: true,
        );
        _showToast("Downloading file: $fileName");
      }
    } else {
      _showToast("Permission denied for download");
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (await webViewController?.canGoBack() ?? false) {
          webViewController?.goBack();
        } else {
          final now = DateTime.now();
          if (lastBackPressedTime == null || now.difference(lastBackPressedTime!) > const Duration(seconds: 2)) {
            lastBackPressedTime = now;
            _showToast("Press once again to exit!");
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(currentUrl), headers: {"X-Access-Type": "webview"}),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                    javaScriptEnabled: true,
                    // domStorageEnabled: true, // **Parameter ini sudah benar dan harusnya tidak error jika versi package sesuai**
                    cacheEnabled: true,
                    userAgent: "App-Webview",
                  ),
                  android: AndroidInAppWebViewOptions(
                    useHybridComposition: false,
                    safeBrowsingEnabled: false, // **PERBAIKAN: Mengoreksi nama parameter dari 'safeBrowseEnabled'**
                  ),
                ),
                onWebViewCreated: (controller) {
                  webViewController = controller;
                  webViewController?.addJavaScriptHandler(
                    handlerName: 'JSAction',
                    callback: (args) {
                      _showToast("Reloading page...");
                      webViewController?.reload();
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    currentUrl = url.toString();
                    progress = 0;
                  });
                },
                onLoadStop: (controller, url) async {
                  setState(() {
                    progress = 1.0;
                  });
                },
                onProgressChanged: (controller, p) {
                  setState(() {
                    progress = p / 100;
                  });
                },
                onLoadError: (controller, url, code, message) {
                  _showToast("Error: $message");
                  webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri('file:///android_asset/flutter_assets/assets/www/error.html')));
                },
                onDownloadStartRequest: (controller, url) async {
                  print("Download started: ${url.url}");
                  await _handleDownload(url.url.toString(), "User-Agent", url.suggestedFilename ?? 'download', url.mimeType ?? '');
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  var uri = navigationAction.request.url;
                  if (uri?.scheme == "whatsapp") {
                    if (await canLaunchUrl(uri!)) {
                      await launchUrl(uri);
                      webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(defaultUrl), headers: {"X-Access-Type": "webview"}));
                      return NavigationActionPolicy.CANCEL;
                    } else {
                      _showToast("Could not open WhatsApp.");
                      return NavigationActionPolicy.CANCEL;
                    }
                  }
                  setState(() {
                    currentUrl = uri.toString();
                  });
                  return NavigationActionPolicy.ALLOW;
                },
              ),
              if (progress < 1.0)
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
            ],
          ),
        ),
      ),
    );
  }
}