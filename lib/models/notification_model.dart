class NotificationModel {
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final String? link;
  final String? messageId;
  final DateTime? receivedAt;

  NotificationModel({
    this.title,
    this.body,
    this.data,
    this.link,
    this.messageId,
    this.receivedAt,
  });

  factory NotificationModel.fromFirebaseMessage(Map<String, dynamic> message) {
    final notification = message['notification'] as Map<String, dynamic>?;
    final data = message['data'] as Map<String, dynamic>?;
    
    return NotificationModel(
      title: notification?['title'],
      body: notification?['body'],
      data: data,
      link: data?['link'],
      messageId: message['messageId'],
      receivedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'data': data,
      'link': link,
      'messageId': messageId,
      'receivedAt': receivedAt?.toIso8601String(),
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      title: json['title'],
      body: json['body'],
      data: json['data'] as Map<String, dynamic>?,
      link: json['link'],
      messageId: json['messageId'],
      receivedAt: json['receivedAt'] != null 
          ? DateTime.parse(json['receivedAt']) 
          : null,
    );
  }

  bool get hasValidLink => 
      link != null && 
      link!.isNotEmpty && 
      (link!.startsWith('http://') || link!.startsWith('https://'));
}