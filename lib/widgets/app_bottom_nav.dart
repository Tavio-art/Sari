import 'package:flutter/material.dart';
import '../services/notification_store.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Inventory'
    ),
    (
      icon: Icons.qr_code_scanner,
      selectedIcon: Icons.qr_code_scanner,
      label: 'Scan'
    ),
    (
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
      label: 'Notif'
    ),
    (
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      label: 'Profile'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF10281F),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: AppColors.mintIcon.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = currentIndex == index;
              final isScan = index == 2;

              if (isScan) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -10),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              item.icon,
                              color: AppColors.darkGreenTop,
                              size: 26,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -4),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.mintIcon
                                  : AppColors.textFaint,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            selected ? item.selectedIcon : item.icon,
                            color: selected
                                ? AppColors.mintIcon
                                : AppColors.textFaint,
                            size: 24,
                          ),
                          if (index == 3)
                            ListenableBuilder(
                              listenable: NotificationStore.instance,
                              builder: (context, _) {
                                final unread =
                                    NotificationStore.instance.unreadCount;
                                if (unread <= 0) return const SizedBox.shrink();
                                return Positioned(
                                  right: -6,
                                  top: -3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentRed,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 14,
                                      minHeight: 14,
                                    ),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? AppColors.mintIcon
                              : AppColors.textFaint,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
