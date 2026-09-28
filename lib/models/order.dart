import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { pending, ready, done }

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.done:
        return 'Done';
    }
  }
}

class StoreOrder {
  final String id;
  final String customerName;
  final int itemCount;
  final double total;
  final OrderStatus status;
  final String paymentMethod;
  final DateTime? createdAt;
  final List<Map<String, dynamic>> items;

  const StoreOrder({
    required this.id,
    required this.customerName,
    required this.itemCount,
    required this.total,
    required this.status,
    this.paymentMethod = '',
    this.createdAt,
    this.items = const [],
  });

  factory StoreOrder.fromFirestore(String id, Map<String, dynamic> data) {
    final rawItems = data['items'];
    final items = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final statusRaw = (data['status'] ?? 'completed').toString().toLowerCase();
    final OrderStatus status;
    if (statusRaw.contains('pending')) {
      status = OrderStatus.pending;
    } else if (statusRaw.contains('ready')) {
      status = OrderStatus.ready;
    } else {
      status = OrderStatus.done;
    }

    DateTime? createdAt;
    final created = data['createdAt'];
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else {
      // Fallback for brand-new writes before serverTimestamp resolves,
      // and for any docs that only have a client millis field.
      final ms = data['createdAtMs'];
      if (ms is num) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
      }
    }

    final itemCount = items.isNotEmpty
        ? items.fold<int>(
            0,
            (total, item) =>
                total + ((item['quantity'] as num?)?.toInt() ?? 0),
          )
        : (data['itemCount'] as num?)?.toInt() ?? 0;

    final name = (data['customerName'] ?? '').toString().trim();

    return StoreOrder(
      id: (data['orderId'] ?? id).toString(),
      customerName: name.isEmpty ? 'Walk-in' : name,
      itemCount: itemCount,
      total: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      status: status,
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      createdAt: createdAt,
      items: items,
    );
  }
}
