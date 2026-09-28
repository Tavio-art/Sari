import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/notification_store.dart';
import 'services/push_notification_service.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase already initialized: $e");
  }

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  await Future.wait([
    SettingsStore.instance.load(),
    NotificationStore.instance.load(),
  ]);

  try {
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Push init skipped: $e');
  }

  runApp(const SariApp());
}

class SariApp extends StatelessWidget {
  const SariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Sari',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          locale: Locale(SettingsStore.instance.languageCode),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}