import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import '../../models/order.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_store.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final FirebaseService _firebase = FirebaseService();
  OrderStatus? _filter;

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.accentOrange;
      case OrderStatus.ready:
        return AppColors.accentBlue;
      case OrderStatus.done:
        return AppColors.mintIcon;
    }
  }

  String _statusFirestoreValue(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.done:
        return 'completed';
    }
  }

  Future<void> _showAddOrderDialog() async {
    final customerController = TextEditingController();
    final totalController = TextEditingController();
    final itemsController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    var payment = 'Cash';
    var status = OrderStatus.done;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.darkGreenMid,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Add Order',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: customerController,
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                        hintText: 'Walk-in',
                      ),
                    ),
                    TextField(
                      controller: totalController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        labelText:
                            'Total (${SettingsStore.instance.currencySymbol})',
                      ),
                    ),
                    TextField(
                      controller: itemsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration:
                          const InputDecoration(labelText: 'Item count'),
                    ),
                    TextField(
                      controller: noteController,
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: const InputDecoration(
                        labelText: 'Note / item description (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: payment,
                      dropdownColor: AppColors.darkGreenMid,
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration:
                          const InputDecoration(labelText: 'Payment method'),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                        DropdownMenuItem(
                            value: 'Credit / Utang',
                            child: Text('Credit / Utang')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() => payment = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<OrderStatus>(
                      initialValue: status,
                      dropdownColor: AppColors.darkGreenMid,
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: OrderStatus.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() => status = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final total =
                              double.tryParse(totalController.text.trim());
                          final count =
                              int.tryParse(itemsController.text.trim()) ?? 1;
                          if (total == null || total < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter a valid total amount.')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final orderId = await _firebase.createManualOrder(
                              customerName: customerController.text.trim(),
                              totalAmount: total,
                              itemCount: count <= 0 ? 1 : count,
                              paymentMethod: payment,
                              status: _statusFirestoreValue(status),
                              userId: FirebaseAuth.instance.currentUser?.uid,
                              note: noteController.text.trim(),
                            );
                            await NotificationStore.instance.add(
                              title: 'Order added',
                              subtitle:
                                  'Manual order ${orderId.substring(0, 8)}… saved.',
                              type: NotificationType.orderReady,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Order added successfully.')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => saving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: AppColors.accentRed,
                                ),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;

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
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textWhite),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Orders',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add Order',
                      onPressed: _showAddOrderDialog,
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppColors.accentOrange),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('All', null),
                      const SizedBox(width: 8),
                      _filterChip('Pending', OrderStatus.pending),
                      const SizedBox(width: 8),
                      _filterChip('Ready', OrderStatus.ready),
                      const SizedBox(width: 8),
                      _filterChip('Done', OrderStatus.done),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListenableBuilder(
                    listenable: settings,
                    builder: (context, _) {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      return StreamBuilder<QuerySnapshot>(
                        stream: uid == null
                            ? const Stream.empty()
                            : _firebase.getOrdersStream(userId: uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.mintIcon),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'May error: ${snapshot.error}',
                                style: const TextStyle(
                                    color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          final orders = (snapshot.data?.docs ?? [])
                              .map((doc) => StoreOrder.fromFirestore(
                                    doc.id,
                                    doc.data() as Map<String, dynamic>,
                                  ))
                              .where((o) =>
                                  _filter == null || o.status == _filter)
                              .toList()
                            ..sort((a, b) {
                              final aTime = a.createdAt ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              final bTime = b.createdAt ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              return bTime.compareTo(aTime);
                            });

                          if (orders.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: AppColors.mintIcon
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No orders found',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _showAddOrderDialog,
                                    child: const Text('Add your first order'),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final o = orders[index];
                              final statusColor = _statusColor(o.status);

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.fieldGreen
                                      .withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.mintIcon
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            o.id,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textFaint,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(
                                              alpha: 0.25,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            o.status.label,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      o.customerName,
                                      style: const TextStyle(
                                        color: AppColors.textWhite,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (o.paymentMethod.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        o.paymentMethod,
                                        style: const TextStyle(
                                          color: AppColors.textFaint,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${o.itemCount} item${o.itemCount == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          settings.formatMoney(o.total),
                                          style: const TextStyle(
                                            color: AppColors.accentOrange,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
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

  Widget _filterChip(String label, OrderStatus? status) {
    final selected = _filter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = status),
      selectedColor: AppColors.accentOrange,
      backgroundColor: AppColors.fieldGreen.withValues(alpha: 0.35),
      shape: StadiumBorder(
        side: BorderSide(
          color: AppColors.mintIcon.withValues(alpha: 0.4),
        ),
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.darkGreenTop : AppColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
