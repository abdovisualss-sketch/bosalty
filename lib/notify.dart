import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a system notification for the moment the focus timer ends, so you
/// are alerted even if the app is in the background or closed (Android / iOS).
/// Every call is wrapped in try/catch: a notification problem never breaks the app.
/// One prayer-time reminder (when to fire + the text to show).
class PrayerAlert {
  const PrayerAlert(this.at, this.title, this.body);
  final DateTime at;
  final String title, body;
}

class Notify {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _id = 7001;

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await a?.requestNotificationsPermission();
      await a?.requestExactAlarmsPermission();
      _ready = true;
    } catch (_) {}
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'timer_done',
      'Focus timer',
      channelDescription: 'Tells you when a focus session ends',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  static Future<void> schedule(DateTime at, String title, String body) async {
    if (!_supported) return;
    try {
      await init();
      await _plugin.cancel(_id);
      final when = tz.TZDateTime.from(at, tz.UTC);
      try {
        await _plugin.zonedSchedule(_id, title, body, when, _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
      } catch (_) {
        // exact alarms not allowed on this device: fall back to an inexact one
        await _plugin.zonedSchedule(_id, title, body, when, _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
      }
    } catch (_) {}
  }

  /// true on Android / iOS, where the system can show scheduled notifications.
  static bool get supported => _supported;

  // Prayer reminders use their own id range (7100..7159) so they never clash with the timer notification (7001).
  static const _prayerBase = 7100;
  static const _prayerSlots = 60;

  static const _prayerDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_time',
      'Prayer reminders',
      channelDescription: 'Reminds you when it is time to pray',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  /// Replaces every scheduled prayer reminder with [items] (only the ones still in the future).
  static Future<void> schedulePrayers(List<PrayerAlert> items) async {
    if (!_supported) return;
    try {
      await init();
      for (var i = 0; i < _prayerSlots; i++) {
        await _plugin.cancel(_prayerBase + i);
      }
      final now = DateTime.now();
      var slot = 0;
      for (final a in items) {
        if (!a.at.isAfter(now)) continue;
        if (slot >= _prayerSlots) break;
        final id = _prayerBase + slot++;
        final when = tz.TZDateTime.from(a.at, tz.UTC);
        try {
          await _plugin.zonedSchedule(id, a.title, a.body, when, _prayerDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
        } catch (_) {
          await _plugin.zonedSchedule(id, a.title, a.body, when, _prayerDetails,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
        }
      }
    } catch (_) {}
  }

  static Future<void> clearPrayers() async {
    if (!_supported) return;
    try {
      for (var i = 0; i < _prayerSlots; i++) {
        await _plugin.cancel(_prayerBase + i);
      }
    } catch (_) {}
  }

  static Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _plugin.cancel(_id);
    } catch (_) {}
  }
}
