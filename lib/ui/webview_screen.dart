import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

import 'package:webview_odoo_push/services/firebase_service.dart';
import 'package:webview_odoo_push/services/api_service.dart';
import 'package:webview_odoo_push/models/notification_model.dart';
import 'package:webview_odoo_push/utils/constants.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;
  double progress = 0;
  String defaultUrl = Constants.defaultWebViewUrl;
  String currentUrl = Constants.defaultWebViewUrl;
  DateTime? lastBackPressedTime;

  late FirebaseService _firebaseService;
  late ApiService _apiService;
  bool _isUserLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _apiService = ApiService();
    
    _initializeServices();
    _requestPermissions();
    _listenForNetworkChanges();
    _setupDownloadListener();
  }

  Future<void> _initializeServices() async {
    // Initialize Firebase service with callbacks
    await _firebaseService.initialize(
      onUrlUpdate: _updateUrlFromNotification,
      onNotificationReceived: _handleNotificationReceived,
    );
  }

  void _updateUrlFromNotification(String url) {
    setState(() {
      defaultUrl = url;
      currentUrl = url;
    });
    webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(currentUrl), 
        headers: {"X-Access-Type": "webview"}
      )
    );
    _showToast("Navigating from notification: $url");
  }

  void _handleNotificationReceived(NotificationModel notification) {
    // Handle notification received callback
    print("Notification received: ${notification.title}");
    if (notification.title != null) {
      _showToast("New notification: ${notification.title}");
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

  /// Check if user has logged in and extract session cookies
  Future<void> _checkLoginAndExtractCookies(String url) async {
    try {
      // Check if URL indicates successful login
      bool isLoginSuccess = _isLoginSuccessUrl(url);
      
      if (isLoginSuccess && !_isUserLoggedIn) {
        print("Login detected, extracting cookies...");
        
        // Extract cookies from WebView
        await _extractAndStoreCookies();
        
        // Mark user as logged in
        _isUserLoggedIn = true;
        
        // Auto-register Firebase token
        await _autoRegisterFirebaseToken();
        
        _showToast("Login successful! Token registered.");
      }
    } catch (e) {
      print("Error in login detection: $e");
    }
  }

  /// Check if the URL indicates successful login
  bool _isLoginSuccessUrl(String url) {
    // Check if we're on the dashboard and not on login page
    return url.contains(Constants.dashboardUrl) && 
           !url.contains(Constants.loginPageUrl) &&
           !url.contains('login');
  }

  /// Extract cookies from WebView and store them
  Future<void> _extractAndStoreCookies() async {
    try {
      if (webViewController != null) {
        // Get cookies from the current domain
        final uri = Uri.parse(currentUrl);
        final cookieManager = CookieManager.instance();
        final cookies = await cookieManager.getCookies(url: WebUri(uri.origin));
        
        if (cookies.isNotEmpty) {
          // Convert cookies to header format
          String cookieHeader = cookies
              .map((cookie) => '${cookie.name}=${cookie.value}')
              .join('; ');
          
          print("Extracted cookies: $cookieHeader");
          
          // Store cookies in API service
          _apiService.setSessionCookies(cookieHeader);
          
          print("Session cookies stored successfully");
        }
      }
    } catch (e) {
      print("Error extracting cookies: $e");
    }
  }

  /// Auto-register Firebase token after login
  Future<void> _autoRegisterFirebaseToken() async {
    try {
      final response = await _firebaseService.autoRegisterAfterLogin();
      
      if (response != null) {
        if (response.isSuccess) {
          print("Firebase token auto-registered successfully");
          _showToast("Device registered for notifications");
        } else {
          print("Failed to auto-register token: ${response.message}");
          _showToast("Failed to register device for notifications");
        }
      }
    } catch (e) {
      print("Error in auto-register Firebase token: $e");
    }
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
                  
                  // Check for login completion and extract cookies
                  await _checkLoginAndExtractCookies(url.toString());
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