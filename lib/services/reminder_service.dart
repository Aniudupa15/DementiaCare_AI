import 'dart:math';
//import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class ReminderService {
  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'reminders_channel', // Channel ID
    'Reminders', // Channel name
    channelDescription: 'Patient reminders and alerts',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize plugin & timezone
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Adjust if needed

    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: initAndroid);
    await _fln.initialize(initSettings);
  }

  /// Ask for notification permission (Android 13+)
  static Future<void> requestPermissionIfNeeded() async {
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedule a one-time alert at [when] (local time)
  static Future<int> scheduleOneTime({
    required String title,
    required String body,
    required DateTime when,
    int? id,
  }) async {
    final nid = id ?? Random().nextInt(1 << 31);
    final tzTime = tz.TZDateTime.from(when, tz.local);

    await _fln.zonedSchedule(
      nid,
      title,
      body,
      tzTime,
      const NotificationDetails(android: _androidDetails),

      // ✅ FIX: Removed deprecated parameters
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

      // In v17+, the following are automatically handled:
      // - time interpretation
      // - date/time components (one-time by default)
    );

    return nid;
  }

  static Future<void> cancel(int id) => _fln.cancel(id);

  static Future<void> cancelAll() => _fln.cancelAll();
}
