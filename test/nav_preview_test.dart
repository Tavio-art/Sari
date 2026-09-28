import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sari_app/models/notification_item.dart';
import 'package:sari_app/services/notification_store.dart';
import 'package:sari_app/widgets/app_bottom_nav.dart';

/// Renders the nav bar to PNGs so the design can be reviewed visually.
/// Run: flutter test --update-goldens test/nav_preview_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nav preview - home selected', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 170));
    tester.view.physicalSize = const Size(412, 170);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0E241C),
          body: const SizedBox.expand(),
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBottomNav),
      matchesGoldenFile('goldens/nav_home.png'),
    );
  });

  testWidgets('nav preview - notifications selected with badge',
      (tester) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.binding.setSurfaceSize(const Size(412, 170));
    tester.view.physicalSize = const Size(412, 170);
    tester.view.devicePixelRatio = 2.0;

    // Seed an unread notification so the badge renders.
    await NotificationStore.instance.add(
      title: 'Low stock',
      subtitle: 'Coke 500ml is running low',
      type: NotificationType.lowStock,
      showSystemBanner: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0E241C),
          body: const SizedBox.expand(),
          bottomNavigationBar: AppBottomNav(
            currentIndex: 3,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBottomNav),
      matchesGoldenFile('goldens/nav_notifications.png'),
    );
  });
}
