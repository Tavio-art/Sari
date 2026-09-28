import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime now) {
    // Monday-based week
    final weekday = now.weekday; // 1=Mon … 7=Sun
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final firebase = FirebaseService();
    final settings = SettingsStore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.textWhite),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox(width: 48),
                    const Text(
                      'Reports & Analytics',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListenableBuilder(
                    listenable: settings,
                    builder: (context, _) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: uid == null
                            ? const Stream.empty()
                            : firebase.getOrdersStream(
                                userId: uid, limit: 200),
                        builder: (context, orderSnap) {
                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: uid == null
                                ? const Stream.empty()
                                : firebase.getCreditsStream(uid),
                            builder: (context, creditSnap) {
                              final now = DateTime.now();
                              final orders = (orderSnap.data?.docs ?? [])
                                  .map((doc) => StoreOrder.fromFirestore(
                                        doc.id,
                                        doc.data() as Map<String, dynamic>,
                                      ))
                                  .toList()
                                ..sort((a, b) {
                                  final aTime = a.createdAt ??
                                      DateTime.fromMillisecondsSinceEpoch(0);
                                  final bTime = b.createdAt ??
                                      DateTime.fromMillisecondsSinceEpoch(0);
                                  return bTime.compareTo(aTime);
                                });

                              double salesToday = 0;
                              int txToday = 0;
                              for (final o in orders) {
                                final when = o.createdAt;
                                if (when != null && _isSameDay(when, now)) {
                                  salesToday += o.total;
                                  txToday++;
                                }
                              }

                              // Net of configured VAT rate (not true COGS profit).
                              final taxFactor =
                                  1 - (settings.taxRate.clamp(0, 100) / 100);
                              final afterTaxToday = salesToday * taxFactor;

                              final waiting = orderSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !orderSnap.hasData;

                              if (waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.mintIcon,
                                  ),
                                );
                              }

                              if (orderSnap.hasError) {
                                return Center(
                                  child: Text(
                                    'Could not load dashboard: ${orderSnap.error}',
                                    style: const TextStyle(
                                        color: AppColors.textMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              double creditBalance = 0;
                              for (final doc
                                  in creditSnap.data?.docs ?? const []) {
                                final data = doc.data();
                                if (data['isPaid'] == true) continue;
                                creditBalance +=
                                    (data['amount'] as num?)?.toDouble() ?? 0;
                              }

                              final weekStart = _startOfWeek(now);
                              final values = List<double>.filled(7, 0);
                              for (final o in orders) {
                                final when = o.createdAt;
                                if (when == null) continue;
                                final day = DateTime(
                                    when.year, when.month, when.day);
                                final diff = day.difference(weekStart).inDays;
                                if (diff >= 0 && diff < 7) {
                                  values[diff] += o.total;
                                }
                              }
                              final maxY = values.fold<double>(
                                  10, (m, v) => v > m ? v : m);

                              final soldByName = <String, int>{};
                              for (final o in orders) {
                                for (final item in o.items) {
                                  final name =
                                      (item['name'] ?? 'Item').toString();
                                  final qty =
                                      (item['quantity'] as num?)?.toInt() ?? 0;
                                  soldByName[name] =
                                      (soldByName[name] ?? 0) + qty;
                                }
                              }
                              final topSelling = soldByName.entries.toList()
                                ..sort((a, b) => b.value.compareTo(a.value));
                              final top3 = topSelling.take(3).toList();

                              const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: StatCard(
                                            label: 'Sales Today',
                                            value: settings
                                                .formatMoney(salesToday),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: StatCard(
                                            label: 'After Tax Today',
                                            value: settings
                                                .formatMoney(afterTaxToday),
                                            valueColor: AppColors.mintIcon,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: StatCard(
                                            label: 'Transactions',
                                            value: '$txToday',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: StatCard(
                                            label: 'Credit Balance',
                                            value: settings
                                                .formatMoney(creditBalance),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'This Week',
                                      style: TextStyle(
                                        color: AppColors.textWhite,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 180,
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 20, 16, 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.fieldGreen
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.mintIcon
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: BarChart(
                                        BarChartData(
                                          maxY: maxY <= 0 ? 10 : maxY * 1.2,
                                          gridData:
                                              const FlGridData(show: false),
                                          borderData:
                                              FlBorderData(show: false),
                                          titlesData: FlTitlesData(
                                            leftTitles: const AxisTitles(
                                              sideTitles: SideTitles(
                                                  showTitles: false),
                                            ),
                                            rightTitles: const AxisTitles(
                                              sideTitles: SideTitles(
                                                  showTitles: false),
                                            ),
                                            topTitles: const AxisTitles(
                                              sideTitles: SideTitles(
                                                  showTitles: false),
                                            ),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  final i = value.toInt();
                                                  if (i < 0 ||
                                                      i >= labels.length) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    child: Text(
                                                      labels[i],
                                                      style: const TextStyle(
                                                        color: AppColors
                                                            .textFaint,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          barGroups:
                                              List.generate(values.length, (i) {
                                            return BarChartGroupData(
                                              x: i,
                                              barRods: [
                                                BarChartRodData(
                                                  toY: values[i],
                                                  width: 16,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  color: AppColors.mintIcon
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ],
                                            );
                                          }),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Top Selling (recent)',
                                      style: TextStyle(
                                        color: AppColors.textWhite,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (top3.isEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.fieldGreen
                                              .withValues(alpha: 0.25),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: const Text(
                                          'No sales yet — complete a checkout to see top products.',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      )
                                    else
                                      ...top3.map(
                                        (item) => Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.fieldGreen
                                                .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: AppColors.mintIcon
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppColors.mintIcon
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.shopping_bag_outlined,
                                                  color: AppColors.mintIcon,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Text(
                                                  item.key,
                                                  style: const TextStyle(
                                                    color: AppColors.textWhite,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${item.value} pcs',
                                                style: const TextStyle(
                                                  color: AppColors.accentOrange,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
