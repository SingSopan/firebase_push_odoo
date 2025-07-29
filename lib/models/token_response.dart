class TokenResponse {
  final String status;
  final String message;
  final int? userId;
  final String? userName;

  TokenResponse({
    required this.status,
    required this.message,
    this.userId,
    this.userName,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      userId: json['user_id'],
      userName: json['user_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'user_id': userId,
      'user_name': userName,
    };
  }

  bool get isSuccess => status == 'success';
}

class TokenRegisterRequest {
  final String token;
  final String os;

  TokenRegisterRequest({
    required this.token,
    required this.os,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'os': os,
    };
  }
}

class TokenUpdateRequest {
  final String oldToken;
  final String newToken;
  final String os;

  TokenUpdateRequest({
    required this.oldToken,
    required this.newToken,
    required this.os,
  });

  Map<String, dynamic> toJson() {
    return {
      'old_token': oldToken,
      'new_token': newToken,
      'os': os,
    };
  }
}

class TokenInfo {
  final String token;
  final String os;
  final int id;

  TokenInfo({
    required this.token,
    required this.os,
    required this.id,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      token: json['token'] ?? '',
      os: json['os'] ?? '',
      id: json['id'] ?? 0,
    );
  }
}

class TokenInfoResponse {
  final String status;
  final String message;
  final int? userId;
  final String? userName;
  final List<TokenInfo> tokens;

  TokenInfoResponse({
    required this.status,
    required this.message,
    this.userId,
    this.userName,
    required this.tokens,
  });

  factory TokenInfoResponse.fromJson(Map<String, dynamic> json) {
    var tokensList = json['tokens'] as List<dynamic>? ?? [];
    List<TokenInfo> tokens = tokensList
        .map((token) => TokenInfo.fromJson(token as Map<String, dynamic>))
        .toList();

    return TokenInfoResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      userId: json['user_id'],
      userName: json['user_name'],
      tokens: tokens,
    );
  }

  bool get isSuccess => status == 'success';
}