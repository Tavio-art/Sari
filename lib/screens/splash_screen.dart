import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';
import '../services/settings_store.dart';
import '../widgets/app_logo.dart';
import 'auth/login_screen.dart';
import 'home/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();


    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
    unawaited(_openNextScreen());
  }

  Future<User?> _restoredUser() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;

    try {
      return await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      return FirebaseAuth.instance.currentUser;
    }
  }

  Future<void> _openNextScreen() async {
    final results = await Future.wait<Object?>([
      Future<void>.delayed(const Duration(seconds: 3)),
      _restoredUser(),
    ]);
    if (!mounted) return;

    final user = results[1] as User?;
    if (user != null) {
      await SettingsStore.instance.reloadForCurrentUser();
      await PushNotificationService.instance.bindTokenToCurrentUser();
    }

    
    try {
      await PushNotificationService.instance.requestPermissionIfNeeded();
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, __) =>
            user != null ? const MainShell() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C241B),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFF0C241B));
              },
            ),
          ),


          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppLogo(size: 84),
                    SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sari',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Color(0xFFF2AD43),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sari-Sari Store Management',
                      style: TextStyle(
                        color: Color(0xFFD0E0D5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}