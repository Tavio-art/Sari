import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import '../../services/cart_store.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../cart/cart_screen.dart';
import '../credit/credit_screen.dart';
import '../inventory/inventory_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const int homeTab = 0;
  static const int inventoryTab = 1;
  static const int scanTab = 2;
  static const int notifTab = 3;
  static const int profileTab = 4;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = MainShell.homeTab;

  @override
  void initState() {
    super.initState();
    CartStore.instance.onOpenCartRequested = _openCart;
    PushNotificationService.instance.onNotificationOpened =
        _handleNotificationOpen;
    final pending = PushNotificationService.instance.consumePendingOpen();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationOpen(pending);
      });
    }
  }

  @override
  void dispose() {
    CartStore.instance.onOpenCartRequested = null;
    if (PushNotificationService.instance.onNotificationOpened ==
        _handleNotificationOpen) {
      PushNotificationService.instance.onNotificationOpened = null;
    }
    super.dispose();
  }

  void _openCart() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  void _openNotif() {
    // Notifications is already a bottom tab — switch to it instead of
    // pushing a second NotificationsScreen on the stack.
    setState(() => _currentIndex = MainShell.notifTab);
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  void _handleNotificationOpen(NotificationType type) {
    if (!mounted) return;
    switch (type) {
      case NotificationType.lowStock:
        setState(() => _currentIndex = MainShell.inventoryTab);
        break;
      case NotificationType.payment:
      case NotificationType.orderReady:
        setState(() => _currentIndex = MainShell.profileTab);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
        break;
      case NotificationType.creditOverdue:
        setState(() => _currentIndex = MainShell.profileTab);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreditScreen()),
        );
        break;
    }
  }

  void _onNotifRelated(NotificationType type) {
    if (type == NotificationType.lowStock) {
      setState(() => _currentIndex = MainShell.inventoryTab);
    } else {
      _handleNotificationOpen(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onOpenCart: _openCart,
            onOpenNotif: _openNotif,
          ),
          const InventoryScreen(),
          ScanScreen(
            onOpenCart: _openCart,
            isActive: _currentIndex == MainShell.scanTab,
          ),
          NotificationsScreen(onOpenRelated: _onNotifRelated),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
