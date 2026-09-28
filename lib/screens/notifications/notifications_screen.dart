import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import '../../services/notification_store.dart';
import '../../theme/app_theme.dart';
import '../credit/credit_screen.dart';
import '../orders/orders_screen.dart';

class NotificationsScreen extends StatefulWidget {
  /// Called for destinations that live on a bottom tab (e.g. Inventory).
  final ValueChanged<NotificationType>? onOpenRelated;

  const NotificationsScreen({super.key, this.onOpenRelated});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;
  final NotificationStore _store = NotificationStore.instance;

  Color _dotColor(NotificationType type) {
    switch (type) {
      case NotificationType.lowStock:
        return AppColors.accentOrange;
      case NotificationType.payment:
        return AppColors.mintIcon;
      case NotificationType.creditOverdue:
        return AppColors.accentRed;
      case NotificationType.orderReady:
        return AppColors.accentBlue;
    }
  }

  IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.lowStock:
        return Icons.inventory_2_outlined;
      case NotificationType.payment:
        return Icons.payments_outlined;
      case NotificationType.creditOverdue:
        return Icons.warning_amber_rounded;
      case NotificationType.orderReady:
        return Icons.receipt_long_outlined;
    }
  }

  Future<void> _onMarkAllRead() async {
    if (_store.unreadCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unread notifications'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await _store.markAllAsRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onClearAll() async {
    if (_store.items.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreenMid,
        title: const Text('Clear all?',
            style: TextStyle(color: AppColors.textWhite)),
        content: const Text(
          'This removes every notification from this device.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications cleared')),
    );
  }

  Future<void> _onTapItem(NotificationItem n) async {
    await _store.markAsRead(n.id);
    if (!mounted) return;

    switch (n.type) {
      case NotificationType.lowStock:
        widget.onOpenRelated?.call(n.type);
        break;
      case NotificationType.payment:
      case NotificationType.orderReady:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
        break;
      case NotificationType.creditOverdue:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreditScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final items = _store.items
                    .where((n) => !_showUnreadOnly || n.unread)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_store.items.isNotEmpty) ...[
                          TextButton(
                            onPressed: _onMarkAllRead,
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(
                                color: AppColors.accentOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: AppColors.textMuted, size: 22),
                            color: AppColors.darkGreenMid,
                            onSelected: (value) {
                              if (value == 'clear') _onClearAll();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'clear',
                                child: Text(
                                  'Clear all',
                                  style: TextStyle(color: AppColors.textWhite),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: !_showUnreadOnly,
                          onSelected: (_) =>
                              setState(() => _showUnreadOnly = false),
                          selectedColor: AppColors.mintIcon,
                          backgroundColor:
                              AppColors.fieldGreen.withValues(alpha: 0.35),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color:
                                  AppColors.mintIcon.withValues(alpha: 0.4),
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: !_showUnreadOnly
                                ? AppColors.darkGreenTop
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            _store.unreadCount > 0
                                ? 'Unread (${_store.unreadCount})'
                                : 'Unread',
                          ),
                          selected: _showUnreadOnly,
                          onSelected: (_) =>
                              setState(() => _showUnreadOnly = true),
                          selectedColor: AppColors.mintIcon,
                          backgroundColor:
                              AppColors.fieldGreen.withValues(alpha: 0.35),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color:
                                  AppColors.mintIcon.withValues(alpha: 0.4),
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: _showUnreadOnly
                                ? AppColors.darkGreenTop
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: !_store.isLoaded
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.mintIcon,
                              ),
                            )
                          : items.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.notifications_none_rounded,
                                        size: 48,
                                        color: AppColors.mintIcon
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _showUnreadOnly
                                            ? 'No unread notifications'
                                            : 'No notifications yet',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Complete a checkout to get a thank-you alert.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.textFaint,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 96),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final n = items[index];
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => _onTapItem(n),
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: n.unread
                                                ? AppColors.fieldGreen
                                                    .withValues(alpha: 0.4)
                                                : AppColors.fieldGreen
                                                    .withValues(alpha: 0.22),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: n.unread
                                                  ? AppColors.mintIcon
                                                      .withValues(alpha: 0.4)
                                                  : AppColors.mintIcon
                                                      .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: _dotColor(n.type)
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  _typeIcon(n.type),
                                                  size: 18,
                                                  color: _dotColor(n.type),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            n.title,
                                                            style: TextStyle(
                                                              color: AppColors
                                                                  .textWhite,
                                                              fontWeight:
                                                                  n.unread
                                                                      ? FontWeight
                                                                          .bold
                                                                      : FontWeight
                                                                          .w500,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        if (n.unread)
                                                          Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: _dotColor(
                                                                  n.type),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      n.subtitle,
                                                      style: const TextStyle(
                                                        color:
                                                            AppColors.textMuted,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      n.displayTime,
                                                      style: const TextStyle(
                                                        color:
                                                            AppColors.textFaint,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: AppColors.textFaint,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
