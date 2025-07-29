import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_odoo_push/models/token_response.dart';
import 'package:webview_odoo_push/utils/constants.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _sessionCookies;

  /// Set session cookies from WebView for authentication
  void setSessionCookies(String cookies) {
    _sessionCookies = cookies;
    _saveSessionCookies(cookies);
    if (kDebugMode) {
      print('API Service: Session cookies updated');
    }
  }

  /// Get headers for API requests including session cookies
  Map<String, String> _getHeaders() {
    final headers = Map<String, String>.from(Constants.defaultHeaders);
    if (_sessionCookies != null && _sessionCookies!.isNotEmpty) {
      headers['Cookie'] = _sessionCookies!;
    }
    return headers;
  }

  /// Save session cookies to SharedPreferences
  Future<void> _saveSessionCookies(String cookies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(Constants.keySessionCookies, cookies);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving session cookies: $e');
      }
    }
  }

  /// Load session cookies from SharedPreferences
  Future<void> loadSessionCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sessionCookies = prefs.getString(Constants.keySessionCookies);
      if (kDebugMode) {
        print('API Service: Loaded session cookies from storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading session cookies: $e');
      }
    }
  }

  /// Register Firebase token with Odoo
  Future<TokenResponse> registerToken(String token) async {
    try {
      final request = TokenRegisterRequest(
        token: token,
        os: Constants.currentPlatform,
      );

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}${Constants.registerTokenEndpoint}'),
        headers: _getHeaders(),
        body: jsonEncode(request.toJson()),
      ).timeout(Constants.apiTimeout);

      if (kDebugMode) {
        print('Register token response: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final tokenResponse = TokenResponse.fromJson(responseData);
        
        if (tokenResponse.isSuccess) {
          await _saveTokenRegistrationData(tokenResponse);
        }
        
        return tokenResponse;
      } else {
        return TokenResponse(
          status: 'error',
          message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on SocketException {
      return TokenResponse(
        status: 'error',
        message: Constants.errorNoInternet,
      );
    } on http.ClientException catch (e) {
      return TokenResponse(
        status: 'error',
        message: 'Network error: ${e.message}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error registering token: $e');
      }
      return TokenResponse(
        status: 'error',
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Update Firebase token with Odoo
  Future<TokenResponse> updateToken(String oldToken, String newToken) async {
    try {
      final request = TokenUpdateRequest(
        oldToken: oldToken,
        newToken: newToken,
        os: Constants.currentPlatform,
      );

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}${Constants.updateTokenEndpoint}'),
        headers: _getHeaders(),
        body: jsonEncode(request.toJson()),
      ).timeout(Constants.apiTimeout);

      if (kDebugMode) {
        print('Update token response: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final tokenResponse = TokenResponse.fromJson(responseData);
        
        if (tokenResponse.isSuccess) {
          await _updateStoredToken(newToken);
        }
        
        return tokenResponse;
      } else {
        return TokenResponse(
          status: 'error',
          message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on SocketException {
      return TokenResponse(
        status: 'error',
        message: Constants.errorNoInternet,
      );
    } on http.ClientException catch (e) {
      return TokenResponse(
        status: 'error',
        message: 'Network error: ${e.message}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error updating token: $e');
      }
      return TokenResponse(
        status: 'error',
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Get token information from Odoo
  Future<TokenInfoResponse> getTokenInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}${Constants.tokenInfoEndpoint}'),
        headers: _getHeaders(),
      ).timeout(Constants.apiTimeout);

      if (kDebugMode) {
        print('Get token info response: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return TokenInfoResponse.fromJson(responseData);
      } else {
        return TokenInfoResponse(
          status: 'error',
          message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          tokens: [],
        );
      }
    } on SocketException {
      return TokenInfoResponse(
        status: 'error',
        message: Constants.errorNoInternet,
        tokens: [],
      );
    } on http.ClientException catch (e) {
      return TokenInfoResponse(
        status: 'error',
        message: 'Network error: ${e.message}',
        tokens: [],
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting token info: $e');
      }
      return TokenInfoResponse(
        status: 'error',
        message: 'Unexpected error: $e',
        tokens: [],
      );
    }
  }

  /// Save token registration data to SharedPreferences
  Future<void> _saveTokenRegistrationData(TokenResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (response.userId != null) {
        await prefs.setInt(Constants.keyUserId, response.userId!);
      }
      if (response.userName != null) {
        await prefs.setString(Constants.keyUserName, response.userName!);
      }
      await prefs.setBool(Constants.keyUserLoggedIn, true);
      await prefs.setString(Constants.keyLastTokenUpdate, DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print('Error saving token registration data: $e');
      }
    }
  }

  /// Update stored token in SharedPreferences
  Future<void> _updateStoredToken(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(Constants.keyFirebaseToken, newToken);
      await prefs.setString(Constants.keyLastTokenUpdate, DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating stored token: $e');
      }
    }
  }

  /// Check if user is logged in and has valid session
  Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(Constants.keyUserLoggedIn) ?? false;
      final hasSessionCookies = _sessionCookies != null && _sessionCookies!.isNotEmpty;
      return isLoggedIn && hasSessionCookies;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking login status: $e');
      }
      return false;
    }
  }

  /// Clear all session data
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(Constants.keySessionCookies);
      await prefs.remove(Constants.keyUserLoggedIn);
      await prefs.remove(Constants.keyUserId);
      await prefs.remove(Constants.keyUserName);
      _sessionCookies = null;
      if (kDebugMode) {
        print('API Service: Session cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing session: $e');
      }
    }
  }
}