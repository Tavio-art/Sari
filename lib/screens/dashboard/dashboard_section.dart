import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import 'dashboard_metrics.dart';

enum _ChartPeriod { week, month, year }

extension on _ChartPeriod {
  String get label {
    switch (this) {
      case _ChartPeriod.week:
        return 'This Week';
      case _ChartPeriod.month:
        return 'This Month';
      case _ChartPeriod.year:
        return 'This Year';
    }
  }

  String get pickerLabel {
    switch (this) {
      case _ChartPeriod.week:
        return 'Week';
      case _ChartPeriod.month:
        return 'Month';
      case _ChartPeriod.year:
        return 'Year';
    }
  }
}

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  static const _weekLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  _ChartPeriod _period = _ChartPeriod.week;

  @override
  Widget build(BuildContext context) {
    final firebase = FirebaseService();
    final settings = SettingsStore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return StreamBuilder<QuerySnapshot>(
          stream: userId == null
              ? const Stream.empty()
              : firebase.getOrdersStream(userId: userId, limit: 200),
          builder: (context, orderSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: userId == null
                  ? const Stream.empty()
                  : firebase.getCreditsStream(userId),
              builder: (context, creditSnapshot) {
                if (orderSnapshot.connectionState == ConnectionState.waiting &&
                    !orderSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.mintIcon),
                    ),
                  );
                }

                if (orderSnapshot.hasError) {
                  return _messageCard(
                    'Could not load dashboard: ${orderSnapshot.error}',
                    color: AppColors.accentRed,
                  );
                }

                final orders = (orderSnapshot.data?.docs
                        .map(
                          (doc) => StoreOrder.fromFirestore(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ),
                        )
                        .toList() ??
                    <StoreOrder>[])
                  ..sort((a, b) {
                    final aTime =
                        a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bTime =
                        b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bTime.compareTo(aTime);
                  });
                final metrics = DashboardMetrics.fromOrders(
                  orders: orders,
                  taxRate: settings.taxRate,
                );
                final creditBalance = creditSnapshot.hasError
                    ? null
                    : DashboardMetrics.unpaidCredit(
                        creditSnapshot.data?.docs
                                .map((doc) => doc.data())
                                .toList() ??
                            const <Map<String, dynamic>>[],
                      );

                final chart = _chartFor(_period, orders, metrics);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Dashboard',
                        style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              height: 108,
                              child: StatCard(
                                label: 'Sales Today',
                                value: settings.formatMoney(metrics.salesToday),
                                icon: Icons.payments_outlined,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              height: 108,
                              child: StatCard(
                                label: 'After Tax Today',
                                value: settings.formatMoney(metrics.afterTaxToday),
                                valueColor: AppColors.mintIcon,
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              height: 108,
                              child: StatCard(
                                label: 'Transactions',
                                value: '${metrics.transactionsToday}',
                                icon: Icons.receipt_long_outlined,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              height: 108,
                              child: StatCard(
                                label: 'Credit Balance',
                                value: creditBalance == null
                                    ? 'Unavailable'
                                    : settings.formatMoney(creditBalance),
                                valueColor: creditBalance == null
                                    ? AppColors.accentRed
                                    : null,
                                icon: Icons.credit_card_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 4, bottom: 10, right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _period.label,
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _periodPicker(),
                        ],
                      ),
                    ),
                    _panel(
                      child: SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            BarChart(
                              chart.data,
                              swapAnimationDuration:
                                  const Duration(milliseconds: 250),
                            ),
                            if (!chart.hasValues)
                              const IgnorePointer(
                                child: Center(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.darkGreenTop,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(16),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'No sales in this period',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Top Selling (recent)',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (metrics.topSellers.isEmpty)
                      _panel(
                        child: const Text(
                          'No sales yet — complete a checkout to see top products.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      _panel(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (var index = 0;
                                index < metrics.topSellers.length;
                                index++) ...[
                              _sellerRow(metrics.topSellers[index], index + 1),
                              if (index < metrics.topSellers.length - 1)
                                Divider(
                                  height: 1,
                                  color:
                                      AppColors.mintIcon.withValues(alpha: 0.14),
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _periodPicker() {
    return PopupMenuButton<_ChartPeriod>(
      initialValue: _period,
      onSelected: (value) => setState(() => _period = value),
      color: AppColors.darkGreenMid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.mintIcon.withValues(alpha: 0.25)),
      ),
      itemBuilder: (context) => _ChartPeriod.values
          .map(
            (period) => PopupMenuItem(
              value: period,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    period.pickerLabel,
                    style: const TextStyle(color: AppColors.textWhite),
                  ),
                  if (period == _period)
                    const Icon(Icons.check_rounded,
                        color: AppColors.accentOrange, size: 18),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.mintIcon.withValues(alpha: 0.35),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _period.pickerLabel,
              style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                color: AppColors.textFaint, size: 18),
          ],
        ),
      ),
    );
  }

  static _ChartResult _chartFor(
    _ChartPeriod period,
    List<StoreOrder> orders,
    DashboardMetrics metrics,
  ) {
    switch (period) {
      case _ChartPeriod.week:
        return _ChartResult(
          values: metrics.weeklySales,
          labels: _weekLabels,
          hasValues: metrics.hasWeeklySales,
        );
      case _ChartPeriod.month:
        return _buildMonthChart(orders);
      case _ChartPeriod.year:
        return _buildYearChart(orders);
    }
  }

  static _ChartResult _buildMonthChart(List<StoreOrder> orders) {
    final now = DateTime.now();
    final values = List<double>.filled(5, 0);
    for (final order in orders) {
      final createdAt = order.createdAt;
      if (createdAt == null) continue;
      if (createdAt.year != now.year || createdAt.month != now.month) continue;
      final weekIndex = ((createdAt.day - 1) ~/ 7).clamp(0, 4);
      values[weekIndex] += order.total;
    }
    final labels = List<String>.generate(5, (i) => 'W${i + 1}');
    return _ChartResult(
      values: values,
      labels: labels,
      hasValues: values.any((v) => v > 0),
    );
  }

  static _ChartResult _buildYearChart(List<StoreOrder> orders) {
    final now = DateTime.now();
    final values = List<double>.filled(12, 0);
    for (final order in orders) {
      final createdAt = order.createdAt;
      if (createdAt == null) continue;
      if (createdAt.year != now.year) continue;
      values[createdAt.month - 1] += order.total;
    }
    final labels = List<String>.generate(
      12,
      (i) => DateFormat('MMM').format(DateTime(now.year, i + 1)),
    );
    return _ChartResult(
      values: values,
      labels: labels,
      hasValues: values.any((v) => v > 0),
    );
  }

  static Widget _messageCard(String message, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: _panel(
        child: Text(
          message,
          style: TextStyle(color: color, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  static Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.darkGreenMid.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: child,
    );
  }

  static Widget _sellerRow(DashboardSeller seller, int rank) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mintIcon.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppColors.mintIcon,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.accentOrange,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              seller.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${seller.quantity} pcs',
            style: const TextStyle(
              color: AppColors.accentOrange,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartResult {
  const _ChartResult({
    required this.values,
    required this.labels,
    required this.hasValues,
  });

  final List<double> values;
  final List<String> labels;
  final bool hasValues;

  BarChartData get data {
    final highestValue = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    final chartMax = highestValue <= 0 ? 10.0 : highestValue * 1.2;

    return BarChartData(
      maxY: chartMax,
      alignment: BarChartAlignment.spaceAround,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final index = group.x.toInt();
            if (index < 0 || index >= labels.length) return null;
            return BarTooltipItem(
              '${labels[index]}\n',
              const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: SettingsStore.instance.formatMoney(values[index]),
                  style: const TextStyle(
                    color: AppColors.mintIcon,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= labels.length) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8,
                child: Text(
                  labels[index],
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: List.generate(values.length, (index) {
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: values[index],
              width: values.length > 7 ? 10 : 16,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.mintIcon.withValues(alpha: 0.55),
                  AppColors.mintIcon,
                ],
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: chartMax,
                color: AppColors.fieldGreen.withValues(alpha: 0.45),
              ),
            ),
          ],
        );
      }),
    );
  }
}