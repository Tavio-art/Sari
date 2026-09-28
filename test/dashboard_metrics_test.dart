import 'package:flutter_test/flutter_test.dart';
import 'package:sari_app/models/order.dart';
import 'package:sari_app/screens/dashboard/dashboard_metrics.dart';

StoreOrder order({
  required String id,
  required double total,
  required DateTime createdAt,
  List<Map<String, dynamic>> items = const [],
}) {
  return StoreOrder(
    id: id,
    customerName: 'Walk-in',
    itemCount: items.fold<int>(
      0,
      (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
    ),
    total: total,
    status: OrderStatus.done,
    createdAt: createdAt,
    items: items,
  );
}

void main() {
  final now = DateTime(2026, 9, 23, 12);

  test('aggregates today, VAT-adjusted sales, and Monday-to-Sunday values', () {
    final metrics = DashboardMetrics.fromOrders(
      now: now,
      taxRate: 12,
      orders: [
        order(
          id: 'monday',
          total: 100,
          createdAt: DateTime(2026, 9, 21),
          items: [
            {'name': 'Coffee', 'quantity': 2},
          ],
        ),
        order(
          id: 'wednesday',
          total: 50,
          createdAt: DateTime(2026, 9, 23, 9),
          items: [
            {'name': 'Tea', 'quantity': 1},
          ],
        ),
        order(
          id: 'previous-week',
          total: 900,
          createdAt: DateTime(2026, 9, 20),
        ),
      ],
    );

    expect(metrics.salesToday, 50);
    expect(metrics.transactionsToday, 1);
    expect(metrics.afterTaxToday, closeTo(44, 0.0001));
    expect(metrics.weeklySales, [100, 0, 50, 0, 0, 0, 0]);
    expect(metrics.hasWeeklySales, isTrue);
  });

  test('retains seven zero-value days for an empty week', () {
    final metrics = DashboardMetrics.fromOrders(
      now: now,
      taxRate: 12,
      orders: const [],
    );

    expect(metrics.weeklySales, hasLength(7));
    expect(metrics.weeklySales, everyElement(0));
    expect(metrics.hasWeeklySales, isFalse);
  });

  test('ranks top sellers deterministically by quantity then name', () {
    final metrics = DashboardMetrics.fromOrders(
      now: now,
      taxRate: 0,
      orders: [
        order(
          id: 'first',
          total: 10,
          createdAt: now,
          items: [
            {'name': 'Zucchini', 'quantity': 2},
            {'name': 'Apple', 'quantity': 2},
          ],
        ),
        order(
          id: 'second',
          total: 10,
          createdAt: now,
          items: [
            {'name': 'Apple', 'quantity': 1},
          ],
        ),
      ],
    );

    expect(
      metrics.topSellers.map((seller) => (seller.name, seller.quantity)),
      [('Apple', 3), ('Zucchini', 2)],
    );
  });

  test('sums only unpaid credit amounts', () {
    final total = DashboardMetrics.unpaidCredit([
      {'amount': 100, 'isPaid': false},
      {'amount': 50, 'isPaid': true},
      {'amount': 25.5},
    ]);

    expect(total, 125.5);
  });
}
