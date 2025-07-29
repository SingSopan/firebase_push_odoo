class ApiResponse<T> {
  final bool success;
  final String status;
  final String message;
  final T? data;
  final int? statusCode;

  ApiResponse({
    required this.success,
    required this.status,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory ApiResponse.success({
    required String message,
    T? data,
    int? statusCode,
  }) {
    return ApiResponse<T>(
      success: true,
      status: 'success',
      message: message,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error({
    required String message,
    T? data,
    int? statusCode,
  }) {
    return ApiResponse<T>(
      success: false,
      status: 'error',
      message: message,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.fromJson(Map<String, dynamic> json, {T? data}) {
    final status = json['status'] ?? 'unknown';
    final isSuccess = status == 'success';
    
    return ApiResponse<T>(
      success: isSuccess,
      status: status,
      message: json['message'] ?? (isSuccess ? 'Success' : 'Unknown error'),
      data: data,
      statusCode: json['status_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'status': status,
      'message': message,
      if (statusCode != null) 'status_code': statusCode,
      if (data != null) 'data': data,
    };
  }

  @override
  String toString() {
    return 'ApiResponse(success: $success, status: $status, message: $message, statusCode: $statusCode)';
  }
}

class TokenRegistrationResponse {
  final int? userId;
  final String? userName;

  TokenRegistrationResponse({
    this.userId,
    this.userName,
  });

  factory TokenRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return TokenRegistrationResponse(
      userId: json['user_id'],
      userName: json['user_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'user_id': userId,
      if (userName != null) 'user_name': userName,
    };
  }
}

class TokenInfoResponse {
  final int userId;
  final String userName;
  final List<Map<String, dynamic>> tokens;

  TokenInfoResponse({
    required this.userId,
    required this.userName,
    required this.tokens,
  });

  factory TokenInfoResponse.fromJson(Map<String, dynamic> json) {
    return TokenInfoResponse(
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? '',
      tokens: List<Map<String, dynamic>>.from(json['tokens'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'tokens': tokens,
    };
  }
}