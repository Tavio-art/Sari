import '../../models/order.dart';

class DashboardSeller {
  const DashboardSeller({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.salesToday,
    required this.transactionsToday,
    required this.afterTaxToday,
    required this.weeklySales,
    required this.topSellers,
  });

  final double salesToday;
  final int transactionsToday;
  final double afterTaxToday;
  final List<double> weeklySales;
  final List<DashboardSeller> topSellers;

  bool get hasWeeklySales => weeklySales.any((value) => value > 0);

  factory DashboardMetrics.fromOrders({
    required Iterable<StoreOrder> orders,
    required double taxRate,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final weekStart = startOfWeek(reference);
    var salesToday = 0.0;
    var transactionsToday = 0;
    final weeklySales = List<double>.filled(7, 0);
    final soldByName = <String, int>{};

    for (final order in orders) {
      final createdAt = order.createdAt;
      if (createdAt != null) {
        if (isSameDay(createdAt, reference)) {
          salesToday += order.total;
          transactionsToday++;
        }

        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        final weekdayOffset = day.difference(weekStart).inDays;
        if (weekdayOffset >= 0 && weekdayOffset < weeklySales.length) {
          weeklySales[weekdayOffset] += order.total;
        }
      }

      for (final item in order.items) {
        final name = (item['name'] ?? 'Item').toString();
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        soldByName[name] = (soldByName[name] ?? 0) + quantity;
      }
    }

    final topSellers = soldByName.entries
        .map((entry) => DashboardSeller(
              name: entry.key,
              quantity: entry.value,
            ))
        .toList()
      ..sort((a, b) {
        final quantityOrder = b.quantity.compareTo(a.quantity);
        return quantityOrder != 0 ? quantityOrder : a.name.compareTo(b.name);
      });

    return DashboardMetrics(
      salesToday: salesToday,
      transactionsToday: transactionsToday,
      afterTaxToday: salesToday * (1 - (taxRate.clamp(0, 100) / 100)),
      weeklySales: weeklySales,
      topSellers: topSellers.take(3).toList(growable: false),
    );
  }

  static double unpaidCredit(Iterable<Map<String, dynamic>> credits) {
    return credits.fold<double>(0, (total, credit) {
      if (credit['isPaid'] == true) return total;
      return total + ((credit['amount'] as num?)?.toDouble() ?? 0);
    });
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime startOfWeek(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    return startOfDay.subtract(Duration(days: date.weekday - 1));
  }
}
