import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

import '../services/firebase_service.dart';
import '../utils/constants.dart';
import '../utils/shared_preferences_helper.dart';

class WebViewWidget extends StatefulWidget {
  final String initialUrl;
  final Function(String)? onUrlChanged;
  final Function(String)? onLoginDetected;
  final Function()? onLogoutDetected;

  const WebViewWidget({
    super.key,
    required this.initialUrl,
    this.onUrlChanged,
    this.onLoginDetected,
    this.onLogoutDetected,
  });

  @override
  State<WebViewWidget> createState() => _WebViewWidgetState();
}

class _WebViewWidgetState extends State<WebViewWidget> {
  InAppWebViewController? webViewController;
  double progress = 0;
  String currentUrl = '';
  
  final FirebaseService _firebaseService = FirebaseService();
  bool _isCheckingLogin = false;

  @override
  void initState() {
    super.initState();
    currentUrl = widget.initialUrl;
    _setupDownloadListener();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setupDownloadListener() {
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    debugPrint('Download task ($id) is in status ($status) and progress ($progress)');
  }

  // Handle download requests
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

  // Show toast message
  void _showToast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Detect login based on URL patterns and page content
  Future<void> _checkForLogin(String url) async {
    if (_isCheckingLogin) return;
    _isCheckingLogin = true;

    try {
      // Check URL patterns for login success
      bool isLoginUrl = Constants.loginSuccessIndicators.any((indicator) => url.contains(indicator));
      
      if (isLoginUrl) {
        debugPrint('Login URL detected: $url');
        
        // Additional check by evaluating JavaScript to confirm login
        final isLoggedIn = await _checkLoginViaJavaScript();
        
        if (isLoggedIn) {
          debugPrint('Login confirmed via JavaScript check');
          await _handleSuccessfulLogin(url);
        }
      }
      
      // Check for logout
      bool isLogoutUrl = Constants.logoutIndicators.any((indicator) => url.contains(indicator));
      if (isLogoutUrl) {
        debugPrint('Logout detected: $url');
        await _handleLogout();
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
    } finally {
      _isCheckingLogin = false;
    }
  }

  // Check login status via JavaScript evaluation
  Future<bool> _checkLoginViaJavaScript() async {
    try {
      if (webViewController == null) return false;

      // Check for common Odoo login indicators
      final jsCode = '''
        (function() {
          // Check for Odoo session cookie
          if (document.cookie.includes('session_id')) {
            return true;
          }
          
          // Check for Odoo user menu or logout button
          var userMenu = document.querySelector('.o_user_menu, .oe_topbar_name, [data-menu="logout"]');
          if (userMenu) {
            return true;
          }
          
          // Check for Odoo main content (not login form)
          var loginForm = document.querySelector('.oe_login_form, .o_database_list');
          var mainContent = document.querySelector('.o_main_content, .o_action_manager');
          
          if (!loginForm && mainContent) {
            return true;
          }
          
          // Check URL doesn't contain login or database selector
          if (!window.location.href.includes('/web/login') && 
              !window.location.href.includes('/web/database')) {
            return true;
          }
          
          return false;
        })();
      ''';

      final result = await webViewController!.evaluateJavascript(source: jsCode);
      return result == true;
    } catch (e) {
      debugPrint('Error evaluating login JavaScript: $e');
      return false;
    }
  }

  // Handle successful login
  Future<void> _handleSuccessfulLogin(String url) async {
    try {
      debugPrint('Handling successful login');
      
      // Extract user information if possible
      await _extractUserInformation();
      
      // Register Firebase token
      await _firebaseService.handleUserLogin();
      
      // Notify parent widget
      widget.onLoginDetected?.call(url);
      
      _showToast('Login successful! Firebase token registered.');
    } catch (e) {
      debugPrint('Error handling successful login: $e');
      _showToast('Login detected but token registration failed');
    }
  }

  // Extract user information from the page
  Future<void> _extractUserInformation() async {
    try {
      if (webViewController == null) return;

      final jsCode = '''
        (function() {
          var userInfo = {};
          
          // Try to get user name from various Odoo elements
          var userName = '';
          var userNameElement = document.querySelector('.oe_topbar_name, .o_user_menu .dropdown-toggle');
          if (userNameElement) {
            userName = userNameElement.textContent.trim();
          }
          
          // Try to get user ID from page data
          var userId = '';
          if (window.odoo && window.odoo.session_info && window.odoo.session_info.uid) {
            userId = window.odoo.session_info.uid;
          }
          
          return {
            userName: userName,
            userId: userId,
            sessionInfo: window.odoo ? window.odoo.session_info : null
          };
        })();
      ''';

      final result = await webViewController!.evaluateJavascript(source: jsCode);
      
      if (result != null && result is Map) {
        final userName = result['userName']?.toString();
        final userId = result['userId']?.toString();
        
        if (userName != null && userName.isNotEmpty) {
          debugPrint('Extracted user name: $userName');
          
          // Save user session
          await SharedPreferencesHelper.saveUserSession(
            userId: userId != null ? int.tryParse(userId) ?? 0 : 0,
            userName: userName,
          );
        }
      }
    } catch (e) {
      debugPrint('Error extracting user information: $e');
    }
  }

  // Handle logout
  Future<void> _handleLogout() async {
    try {
      debugPrint('Handling logout');
      
      // Clear user session
      await _firebaseService.handleUserLogout();
      
      // Notify parent widget
      widget.onLogoutDetected?.call();
      
      _showToast('Logged out');
    } catch (e) {
      debugPrint('Error handling logout: $e');
    }
  }

  // Handle navigation to new URL
  void _navigateToUrl(String url) {
    setState(() {
      currentUrl = url;
    });
    webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(url),
        headers: {"X-Access-Type": "webview"},
      ),
    );
    widget.onUrlChanged?.call(url);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(currentUrl),
            headers: {"X-Access-Type": "webview"},
          ),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              javaScriptEnabled: true,
              cacheEnabled: true,
              userAgent: "App-Webview",
            ),
            android: AndroidInAppWebViewOptions(
              useHybridComposition: false,
              safeBrowsingEnabled: false,
            ),
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
            
            // Add JavaScript handler for manual actions
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
            widget.onUrlChanged?.call(currentUrl);
          },
          onLoadStop: (controller, url) async {
            setState(() {
              progress = 1.0;
            });
            
            // Check for login after page load
            await _checkForLogin(url.toString());
          },
          onProgressChanged: (controller, p) {
            setState(() {
              progress = p / 100;
            });
          },
          onLoadError: (controller, url, code, message) {
            _showToast("Error: $message");
            // Load error page
            webViewController?.loadUrl(
              urlRequest: URLRequest(
                url: WebUri('file:///android_asset/flutter_assets/assets/www/error.html'),
              ),
            );
          },
          onDownloadStartRequest: (controller, url) async {
            debugPrint("Download started: ${url.url}");
            await _handleDownload(
              url.url.toString(),
              "User-Agent",
              url.suggestedFilename ?? 'download',
              url.mimeType ?? '',
            );
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            var uri = navigationAction.request.url;
            
            // Handle special URL schemes
            if (uri?.scheme == "whatsapp") {
              if (await canLaunchUrl(uri!)) {
                await launchUrl(uri);
                // Return to previous page
                webViewController?.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri(widget.initialUrl),
                    headers: {"X-Access-Type": "webview"},
                  ),
                );
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
    );
  }

  // Public method to navigate to URL (for external calls like notifications)
  void navigateToUrl(String url) {
    _navigateToUrl(url);
  }

  // Public method to reload current page
  void reload() {
    webViewController?.reload();
  }

  // Public method to go back
  Future<bool> goBack() async {
    if (await webViewController?.canGoBack() ?? false) {
      webViewController?.goBack();
      return true;
    }
    return false;
  }
}