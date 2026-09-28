import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/notification_item.dart';
import 'notification_store.dart';
import 'settings_store.dart';

/// Handles OS notification permission, FCM token registration, and local
/// notification display for in-app events.
///
/// Backend: deploy `functions/index.js` → `sendPushToUser` (or call Admin SDK)
/// to send FCM to `users/{uid}.fcmToken` when `users/{uid}.settings.push` is true.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[FCM] background Firebase init: $e');
  }
  debugPrint('[FCM] background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _askedKey = 'notif_permission_asked_v1';
  static const _channelId = 'sari_alerts';
  static const _channelName = 'Sari Alerts';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSub;
  final Set<String> _ingestedRemoteIds = {};

  /// Fired when the user opens a system / local notification.
  void Function(NotificationType type)? onNotificationOpened;

  /// Queued when a tap arrives before [onNotificationOpened] is set (cold start).
  NotificationType? _pendingOpenType;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  NotificationType? consumePendingOpen() {
    final pending = _pendingOpenType;
    _pendingOpenType = null;
    return pending;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[Push] background handler register skipped: $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Order, stock, and payment alerts',
              importance: Importance.high,
            ),
          );
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // Cold-start from a notification tap.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await _ingestRemoteMessage(initial, markUnread: false);
      _queueOpen(_typeFromData(initial.data));
    }

    // Local notification that launched the app.
    final launchDetails = await _local.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _queueOpen(_typeFromName(payload));
      }
    }

    _initialized = true;
  }

  /// First-run prompt after splash / login. Safe if already asked or denied.
  Future<void> requestPermissionIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) == true) {
      await _syncTokenIfAllowed();
      return;
    }

    await prefs.setBool(_askedKey, true);
    final granted = await requestPermission();
    if (granted) {
      await SettingsStore.instance.setPush(true);
    } else {
      await SettingsStore.instance.setPush(false);
    }
  }

  /// Shows the platform permission dialog. Returns true if notifications
  /// are allowed. Never throws.
  Future<bool> requestPermission() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            debugPrint('[Push] Android notification permission denied');
            return false;
          }
        }
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (authorized) {
        await _syncTokenIfAllowed();
      }
      return authorized;
    } catch (e) {
      debugPrint('[Push] requestPermission failed: $e');
      return false;
    }
  }

  Future<AuthorizationStatus> currentAuthorizationStatus() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (_) {
      return AuthorizationStatus.notDetermined;
    }
  }

  Future<bool> get isOsPermissionGranted async {
    final status = await currentAuthorizationStatus();
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// Enable push from Settings: request OS permission if needed, then persist.
  Future<bool> enableFromSettings() async {
    final granted = await requestPermission();
    if (granted) {
      await SettingsStore.instance.setPush(true);
      return true;
    }
    await SettingsStore.instance.setPush(false);
    return false;
  }

  Future<void> disableFromSettings() async {
    await SettingsStore.instance.setPush(false);
    // Keep token registered so re-enabling is fast; server should check
    // users/{uid}.settings.push before sending.
  }

  /// Open system app settings when the user previously denied permission.
  Future<void> openSystemSettings() => openAppSettings();

  Future<void> _syncTokenIfAllowed() async {
    try {
      if (kIsWeb) {
        // Web needs a VAPID key configured in Firebase Console — skip quietly.
        return;
      }
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null && _fcmToken!.length > 12) {
        debugPrint('[Push] FCM token: ${_fcmToken!.substring(0, 12)}…');
      }
      await _persistToken(_fcmToken);
      _tokenRefreshSub ??= _messaging.onTokenRefresh.listen(_persistToken);
    } catch (e) {
      debugPrint('[Push] getToken failed: $e');
    }
  }

  Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    _fcmToken = token;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': {token: FieldValue.serverTimestamp()},
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Push] persist token failed: $e');
    }
  }

  /// Call after login so the token is tied to the signed-in user.
  Future<void> bindTokenToCurrentUser() => _syncTokenIfAllowed();

  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!SettingsStore.instance.pushEnabled) return;
    if (!await isOsPermissionGranted) return;

    try {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Order, stock, and payment alerts',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[Push] local show failed: $e');
    }
  }

  void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _queueOpen(_typeFromName(payload));
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    await _ingestRemoteMessage(message, markUnread: true);
    final n = message.notification;
    if (n != null) {
      await showLocal(
        title: n.title ?? 'Sari',
        body: n.body ?? '',
        payload: message.data['type']?.toString() ?? 'payment',
      );
    }
  }

  Future<void> _onMessageOpened(RemoteMessage message) async {
    await _ingestRemoteMessage(message, markUnread: false);
    _queueOpen(_typeFromData(message.data));
  }

  void _queueOpen(NotificationType type) {
    if (onNotificationOpened != null) {
      onNotificationOpened!(type);
    } else {
      _pendingOpenType = type;
    }
  }

  NotificationType _typeFromData(Map<String, dynamic> data) {
    return _typeFromName(data['type']?.toString());
  }

  NotificationType _typeFromName(String? typeName) {
    return NotificationType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => NotificationType.payment,
    );
  }

  Future<void> _ingestRemoteMessage(
    RemoteMessage message, {
    required bool markUnread,
  }) async {
    final remoteId = message.messageId;
    if (remoteId != null && remoteId.isNotEmpty) {
      if (_ingestedRemoteIds.contains(remoteId)) return;
      _ingestedRemoteIds.add(remoteId);
      if (_ingestedRemoteIds.length > 50) {
        _ingestedRemoteIds.remove(_ingestedRemoteIds.first);
      }
    }

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Notification';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';
    final type = _typeFromData(message.data);

    // Avoid duplicating an identical unread item already in the store.
    final store = NotificationStore.instance;
    final already = store.items.any(
      (n) =>
          n.title == title &&
          n.subtitle == (body.isEmpty ? 'Tap to view details' : body) &&
          n.unread,
    );
    if (already) {
      if (!markUnread) {
        final match = store.items.firstWhere(
          (n) => n.title == title && n.unread,
          orElse: () => store.items.first,
        );
        if (match.id.isNotEmpty) await store.markAsRead(match.id);
      }
      return;
    }

    await store.add(
      title: title,
      subtitle: body.isEmpty ? 'Tap to view details' : body,
      type: type,
      showSystemBanner: false,
    );

    if (!markUnread && store.items.isNotEmpty) {
      await store.markAsRead(store.items.first.id);
    }
  }
}
