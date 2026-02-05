import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {

  static final FirebaseMessaging _fcm =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin
  _local = FlutterLocalNotificationsPlugin();

  // Init
  static Future<void> init() async {

    // Permission (Android 13+)
    await _fcm.requestPermission();

    // Local notification setup
    const android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings =
    InitializationSettings(android: android);

    await _local.initialize(settings);

    // Foreground handler
    FirebaseMessaging.onMessage.listen((message) {
      _showLocal(message);
    });
  }

  // Get token
  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  // Show notification
  static Future<void> _showLocal(
      RemoteMessage message,
      ) async {

    const androidDetails =
    AndroidNotificationDetails(
      'drch_channel',
      'Disaster Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details =
    NotificationDetails(android: androidDetails);

    await _local.show(
      0,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }
}
