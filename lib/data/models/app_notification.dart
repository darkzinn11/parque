import 'dart:convert';

class AppNotification {
  final String id;
  final String type; // 'reservation_status' | 'event' | 'general'
  final String title;
  final String body;
  final String? deeplink;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.deeplink,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        deeplink: deeplink,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'deeplink': deeplink,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'general',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        deeplink: json['deeplink'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.tryParse(
                json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  static String encodeList(List<AppNotification> list) =>
      jsonEncode(list.map((n) => n.toJson()).toList());

  static List<AppNotification> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) {
          try {
            return AppNotification.fromJson(e as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<AppNotification>()
        .toList();
  }
}
