import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/app_notification.dart';

class NotificationProvider extends ChangeNotifier {
  static const _key = 'app_notifications';
  static const _maxItems = 50;

  static int _idCounter = 0;

  static String generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get hasUnread => _notifications.any((n) => !n.isRead);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      _notifications = AppNotification.decodeList(raw);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> add(AppNotification notification) async {
    _notifications = [notification, ..._notifications];
    if (_notifications.length > _maxItems) {
      _notifications = _notifications.sublist(0, _maxItems);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead() async {
    if (!hasUnread) return;
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _notifications = _notifications.where((n) => n.id != id).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    _notifications = [];
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, AppNotification.encodeList(_notifications));
  }
}
