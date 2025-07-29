class FirebaseTokenModel {
  final String token;
  final String os;
  final int? userId;
  final String? userName;
  final DateTime? dateRegistered;

  FirebaseTokenModel({
    required this.token,
    required this.os,
    this.userId,
    this.userName,
    this.dateRegistered,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'os': os,
      if (userId != null) 'user_id': userId,
      if (userName != null) 'user_name': userName,
      if (dateRegistered != null) 'date': dateRegistered!.toIso8601String(),
    };
  }

  factory FirebaseTokenModel.fromJson(Map<String, dynamic> json) {
    return FirebaseTokenModel(
      token: json['token'] ?? '',
      os: json['os'] ?? 'android',
      userId: json['user_id'],
      userName: json['user_name'],
      dateRegistered: json['date'] != null ? DateTime.parse(json['date']) : null,
    );
  }

  FirebaseTokenModel copyWith({
    String? token,
    String? os,
    int? userId,
    String? userName,
    DateTime? dateRegistered,
  }) {
    return FirebaseTokenModel(
      token: token ?? this.token,
      os: os ?? this.os,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      dateRegistered: dateRegistered ?? this.dateRegistered,
    );
  }

  @override
  String toString() {
    return 'FirebaseTokenModel(token: ${token.substring(0, 10)}..., os: $os, userId: $userId, userName: $userName)';
  }
}