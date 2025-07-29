import 'package:flutter_test/flutter_test.dart';
import 'package:webview_odoo_push/models/firebase_token_model.dart';
import 'package:webview_odoo_push/models/api_response_model.dart';
import 'package:webview_odoo_push/services/api_service.dart';

void main() {
  group('Firebase Token Model Tests', () {
    test('FirebaseTokenModel should create from JSON correctly', () {
      final json = {
        'token': 'test_token_12345',
        'os': 'android',
        'user_id': 1,
        'user_name': 'Test User',
        'date': '2024-01-01T00:00:00.000Z',
      };

      final tokenModel = FirebaseTokenModel.fromJson(json);

      expect(tokenModel.token, equals('test_token_12345'));
      expect(tokenModel.os, equals('android'));
      expect(tokenModel.userId, equals(1));
      expect(tokenModel.userName, equals('Test User'));
      expect(tokenModel.dateRegistered, isNotNull);
    });

    test('FirebaseTokenModel should convert to JSON correctly', () {
      final tokenModel = FirebaseTokenModel(
        token: 'test_token_12345',
        os: 'android',
        userId: 1,
        userName: 'Test User',
        dateRegistered: DateTime.parse('2024-01-01T00:00:00.000Z'),
      );

      final json = tokenModel.toJson();

      expect(json['token'], equals('test_token_12345'));
      expect(json['os'], equals('android'));
      expect(json['user_id'], equals(1));
      expect(json['user_name'], equals('Test User'));
      expect(json['date'], isNotNull);
    });

    test('FirebaseTokenModel copyWith should work correctly', () {
      final original = FirebaseTokenModel(
        token: 'original_token',
        os: 'android',
      );

      final updated = original.copyWith(
        token: 'new_token',
        userId: 123,
      );

      expect(updated.token, equals('new_token'));
      expect(updated.os, equals('android')); // Should preserve original
      expect(updated.userId, equals(123));
    });
  });

  group('API Response Model Tests', () {
    test('ApiResponse should create success response correctly', () {
      final response = ApiResponse.success(
        message: 'Success',
        data: {'key': 'value'},
        statusCode: 200,
      );

      expect(response.success, isTrue);
      expect(response.status, equals('success'));
      expect(response.message, equals('Success'));
      expect(response.statusCode, equals(200));
    });

    test('ApiResponse should create error response correctly', () {
      final response = ApiResponse.error(
        message: 'Error occurred',
        statusCode: 400,
      );

      expect(response.success, isFalse);
      expect(response.status, equals('error'));
      expect(response.message, equals('Error occurred'));
      expect(response.statusCode, equals(400));
    });

    test('ApiResponse should parse from JSON correctly', () {
      final json = {
        'status': 'success',
        'message': 'Operation successful',
        'status_code': 200,
      };

      final response = ApiResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.status, equals('success'));
      expect(response.message, equals('Operation successful'));
    });
  });

  group('Token Registration Response Tests', () {
    test('TokenRegistrationResponse should parse correctly', () {
      final json = {
        'user_id': 123,
        'user_name': 'John Doe',
      };

      final response = TokenRegistrationResponse.fromJson(json);

      expect(response.userId, equals(123));
      expect(response.userName, equals('John Doe'));
    });
  });

  group('Token Info Response Tests', () {
    test('TokenInfoResponse should parse correctly', () {
      final json = {
        'user_id': 123,
        'user_name': 'John Doe',
        'tokens': [
          {'token': 'token1', 'os': 'android', 'id': 1},
          {'token': 'token2', 'os': 'ios', 'id': 2},
        ],
      };

      final response = TokenInfoResponse.fromJson(json);

      expect(response.userId, equals(123));
      expect(response.userName, equals('John Doe'));
      expect(response.tokens.length, equals(2));
      expect(response.tokens[0]['token'], equals('token1'));
      expect(response.tokens[1]['os'], equals('ios'));
    });
  });
}