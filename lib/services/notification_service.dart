import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/supabase_config.dart';

class NotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    await _requestPermission();
    await _initLocalNotifications();
    await _saveFcmToken();
    _listenForeground();
  }

  static Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // High-importance channel for Android
    const channel = AndroidNotificationChannel(
      'civiclens_high',
      'CivicLens Alerts',
      description: 'Civic reports and appreciation notifications',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _saveFcmToken() async {
    final token = await _messaging.getToken();
    if (token == null) return;

    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    await SupabaseConfig.client
        .from('user_fcm_tokens')
        .upsert({'user_id': userId, 'token': token, 'updated_at': DateTime.now().toIso8601String()});

    // Refresh token when it rotates
    _messaging.onTokenRefresh.listen((newToken) async {
      await SupabaseConfig.client
          .from('user_fcm_tokens')
          .upsert({'user_id': userId, 'token': newToken, 'updated_at': DateTime.now().toIso8601String()});
    });
  }

  static void _listenForeground() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'civiclens_high',
            'CivicLens Alerts',
            channelDescription: 'Civic reports and appreciation notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  static Future<void> subscribeToCity(String citySlug) async {
    await _messaging.subscribeToTopic('city_$citySlug');
  }

  static Future<void> unsubscribeFromCity(String citySlug) async {
    await _messaging.unsubscribeFromTopic('city_$citySlug');
  }
}
