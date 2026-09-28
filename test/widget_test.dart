import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sari_app/widgets/app_bottom_nav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppBottomNav shows all tab labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Notif'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
