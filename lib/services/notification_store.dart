import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_item.dart';
import 'push_notification_service.dart';
import 'settings_store.dart';

/// In-app notifications (checkout thank-you, low stock, etc.).
class NotificationStore extends ChangeNotifier {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  static const _prefsKey = 'app_notifications_v1';

  final List<NotificationItem> _items = [];
  bool _loaded = false;

  List<NotificationItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  int get unreadCount => _items.where((n) => n.unread).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final entry in list) {
          if (entry is Map<String, dynamic>) {
            _items.add(NotificationItem.fromMap(entry));
          } else if (entry is Map) {
            _items.add(NotificationItem.fromMap(
              Map<String, dynamic>.from(entry),
            ));
          }
        }
      } catch (e) {
        debugPrint('[NotificationStore] parse failed: $e');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((e) => e.toMap()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  /// Whether this notification type should be recorded given user settings.
  bool _allowedBySettings(NotificationType type) {
    final settings = SettingsStore.instance;
    switch (type) {
      case NotificationType.lowStock:
        return settings.lowStockEnabled;
      case NotificationType.payment:
      case NotificationType.creditOverdue:
      case NotificationType.orderReady:
        // Always keep in-app history; system banners still gated by pushEnabled.
        return true;
    }
  }

  Future<void> add({
    required String title,
    required String subtitle,
    required NotificationType type,
    String? timeAgo,
    bool showSystemBanner = true,
  }) async {
    if (!_allowedBySettings(type)) return;

    _items.insert(
      0,
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        subtitle: subtitle,
        timeAgo: timeAgo ?? 'Just now',
        type: type,
        unread: true,
        createdAt: DateTime.now(),
      ),
    );
    // Keep last 100
    if (_items.length > 100) {
      _items.removeRange(100, _items.length);
    }
    notifyListeners();
    await _persist();

    if (showSystemBanner && SettingsStore.instance.pushEnabled) {
      await PushNotificationService.instance.showLocal(
        title: title,
        body: subtitle,
        payload: type.name,
      );
    }
  }

  Future<void> addCheckoutThankYou({
    required String orderId,
    required double total,
    required String paymentMethod,
    String customerName = '',
  }) async {
    final who = customerName.trim().isEmpty ? 'customer' : customerName.trim();
    final shortId =
        orderId.length > 8 ? '${orderId.substring(0, 8)}…' : orderId;
    final money = SettingsStore.instance.formatMoney(total);
    await add(
      title: 'Thank you!',
      subtitle:
          'Order $shortId for $who via $paymentMethod ($money) completed.',
      type: NotificationType.payment,
    );
  }

  Future<void> addLowStockAlert({
    required String productName,
    required int stock,
  }) async {
    if (!SettingsStore.instance.lowStockEnabled) return;
    final already = _items.any(
      (n) =>
          n.type == NotificationType.lowStock &&
          n.unread &&
          n.subtitle.contains(productName),
    );
    if (already) return;

    await add(
      title: stock <= 0 ? 'Out of stock' : 'Low stock',
      subtitle: stock <= 0
          ? '$productName is out of stock.'
          : '$productName has only $stock left.',
      type: NotificationType.lowStock,
    );
  }

  /// One unread overdue alert per credit id (subtitle embeds the id).
  Future<void> addCreditOverdueAlert({
    required String creditId,
    required String customerName,
    required double amount,
    required int daysOverdue,
  }) async {
    final already = _items.any(
      (n) =>
          n.type == NotificationType.creditOverdue &&
          n.subtitle.contains(creditId),
    );
    if (already) return;

    final money = SettingsStore.instance.formatMoney(amount);
    await add(
      title: 'Credit overdue',
      subtitle:
          '$customerName owes $money ($daysOverdue days). #$creditId',
      type: NotificationType.creditOverdue,
    );
  }

  Future<void> markAsRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || !_items[i].unread) return;
    _items[i] = _items[i].copyWith(unread: false);
    notifyListeners();
    await _persist();
  }

  Future<void> markAllAsRead() async {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].unread) {
        _items[i] = _items[i].copyWith(unread: false);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
    await _persist();
  }
}
