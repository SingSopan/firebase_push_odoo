import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/api_response_model.dart';
import '../models/firebase_token_model.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  // Register Firebase token with Odoo server
  Future<ApiResponse<TokenRegistrationResponse>> registerToken(
    FirebaseTokenModel tokenModel,
  ) async {
    try {
      final response = await _makeRequest(
        endpoint: Constants.tokenRegisterEndpoint,
        method: 'POST',
        data: tokenModel.toJson(),
      );

      if (response.success) {
        final registrationData = TokenRegistrationResponse.fromJson(
          response.data as Map<String, dynamic>? ?? {},
        );
        return ApiResponse.success(
          message: response.message,
          data: registrationData,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(
        message: 'Failed to register token: $e',
      );
    }
  }

  // Update Firebase token
  Future<ApiResponse<void>> updateToken(
    String oldToken,
    String newToken, {
    String? os,
  }) async {
    try {
      final data = {
        'old_token': oldToken,
        'new_token': newToken,
        'os': os ?? Constants.deviceOS,
      };

      final response = await _makeRequest(
        endpoint: Constants.tokenUpdateEndpoint,
        method: 'POST',
        data: data,
      );

      if (response.success) {
        return ApiResponse.success(
          message: response.message,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(
        message: 'Failed to update token: $e',
      );
    }
  }

  // Get token information
  Future<ApiResponse<TokenInfoResponse>> getTokenInfo() async {
    try {
      final response = await _makeRequest(
        endpoint: Constants.tokenInfoEndpoint,
        method: 'GET',
      );

      if (response.success) {
        final tokenInfo = TokenInfoResponse.fromJson(
          response.data as Map<String, dynamic>? ?? {},
        );
        return ApiResponse.success(
          message: response.message,
          data: tokenInfo,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(
        message: 'Failed to get token info: $e',
      );
    }
  }

  // Generic HTTP request method
  Future<ApiResponse<dynamic>> _makeRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    int retryCount = 0,
  }) async {
    final url = Uri.parse('${Constants.odooBaseUrl}$endpoint');
    final requestHeaders = {
      ...Constants.defaultHeaders,
      ...?headers,
    };

    try {
      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client
              .get(url, headers: requestHeaders)
              .timeout(Constants.requestTimeout);
          break;
        case 'POST':
          response = await _client
              .post(
                url,
                headers: requestHeaders,
                body: data != null ? jsonEncode(data) : null,
              )
              .timeout(Constants.requestTimeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      return _handleResponse(response);
    } on SocketException catch (e) {
      if (retryCount < Constants.maxRetryAttempts) {
        await Future.delayed(Constants.retryDelay);
        return _makeRequest(
          endpoint: endpoint,
          method: method,
          data: data,
          headers: headers,
          retryCount: retryCount + 1,
        );
      }
      return ApiResponse.error(
        message: 'Network error: ${e.message}',
      );
    } on HttpException catch (e) {
      return ApiResponse.error(
        message: 'HTTP error: ${e.message}',
      );
    } catch (e) {
      if (retryCount < Constants.maxRetryAttempts) {
        await Future.delayed(Constants.retryDelay);
        return _makeRequest(
          endpoint: endpoint,
          method: method,
          data: data,
          headers: headers,
          retryCount: retryCount + 1,
        );
      }
      return ApiResponse.error(
        message: 'Request failed: $e',
      );
    }
  }

  // Handle HTTP response
  ApiResponse<dynamic> _handleResponse(http.Response response) {
    try {
      final statusCode = response.statusCode;
      
      if (statusCode >= 200 && statusCode < 300) {
        if (response.body.isEmpty) {
          return ApiResponse.success(
            message: 'Success',
            statusCode: statusCode,
          );
        }

        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.fromJson(jsonData, data: jsonData);
      } else {
        String errorMessage = 'HTTP Error $statusCode';
        
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = jsonData['message'] ?? errorMessage;
        } catch (e) {
          // If response body is not JSON, use status code message
          errorMessage = 'HTTP Error $statusCode: ${response.reasonPhrase}';
        }

        return ApiResponse.error(
          message: errorMessage,
          statusCode: statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(
        message: 'Failed to parse response: $e',
        statusCode: response.statusCode,
      );
    }
  }

  // Legacy XML-RPC method (keeping for compatibility)
  Future<ApiResponse<void>> sendTokenViaXmlRpc(String token) async {
    try {
      final payload = '''
        <?xml version="1.0"?>
        <methodCall>
            <methodName>call</methodName>
            <params>
                <param><value><string>${Constants.odooDatabase}</string></value></param>
                <param><value><int>1</int></value></param>
                <param><value><string>${Constants.odooPassword}</string></value></param>
                <param><value><string>push.notification.token</string></value></param>
                <param><value><string>create</string></value></param>
                <param><value><array><data><value><struct>
                    <member><n>token</n><value><string>$token</string></value></member>
                    <member><n>date</n><value><string>${DateTime.now().toIso8601String()}</string></value></member>
                </struct></value></data></array></value></param>
            </params>
        </methodCall>
      ''';

      final response = await _client
          .post(
            Uri.parse('${Constants.odooBaseUrl}${Constants.xmlRpcEndpoint}'),
            headers: Constants.xmlRpcHeaders,
            body: payload,
          )
          .timeout(Constants.requestTimeout);

      if (response.statusCode == 200) {
        return ApiResponse.success(
          message: 'Token sent via XML-RPC successfully',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          message: 'XML-RPC failed with status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(
        message: 'XML-RPC request failed: $e',
      );
    }
  }

  // Close HTTP client
  void dispose() {
    _client.close();
  }
}