import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One prayer-time reminder (when to fire + the text to show).
class PrayerAlert {
  const PrayerAlert(this.at, this.title, this.body);
  final DateTime at;
  final String title, body;
}

/// Schedules system notifications (Android / iOS): the moment a focus timer ends, and prayer times.
/// Every call is wrapped in try/catch: a notification problem never breaks the app.
class Notify {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _initFuture;
  static const _id = 7001;

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Safe to call many times (and without await): the setup runs once.
  static Future<void> init() {
    if (!_supported) return Future.value();
    return _initFuture ??= _init();
  }

  static Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    } catch (_) {
      _initFuture = null; // let the next call try again
      return;
    }
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  /// true on Android / iOS, where the system can show scheduled notifications.
  static bool get supported => _supported;

  /// false when the user switched notifications off for the app in the phone settings.
  static Future<bool> canNotify() async {
    if (!_supported) return false;
    try {
      await init();
      return await _android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  // ---------------------------------------------------------------- focus timer

  // On Android 8+ the sound belongs to the notification *channel* and can't be changed after the
  // channel is created. So every tone gets its own channel: timer_done_<tone id>.
  static const _timerChannelPrefix = 'timer_done_';
  static const _systemTone = 'system';

  /// Builds the notification settings for [tone] (a tone id from TimerSounds). Needs these files:
  ///   Android: android/app/src/main/res/raw/timer_<tone>.wav
  ///   iOS:     timer_<tone>.wav added to the Runner target
  static Future<NotificationDetails> _timerDetails(String tone, bool sound) async {
    final custom = sound && tone != _systemTone;
    final channelId = sound ? '$_timerChannelPrefix$tone' : '${_timerChannelPrefix}silent';
    final channelName = sound ? 'Focus timer ($tone)' : 'Focus timer (silent)';
    const channelDesc = 'Tells you when a focus session ends';
    final androidSound = custom ? RawResourceAndroidNotificationSound('timer_$tone') : null;

    final a = _android;
    if (a != null) {
      try {
        await a.createNotificationChannel(AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDesc,
          importance: Importance.max,
          playSound: sound,
          sound: androidSound,
          // plays on the alarm volume, like a normal timer
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ));
        // drop the channels of the tones that are no longer selected (keeps the phone's settings tidy)
        final all = await a.getNotificationChannels() ?? [];
        for (final c in all) {
          if (c.id.startsWith(_timerChannelPrefix) && c.id != channelId) {
            await a.deleteNotificationChannel(c.id);
          }
        }
        await a.deleteNotificationChannel('timer_done'); // the old single channel
      } catch (_) {}
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: sound,
        sound: androidSound,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: sound,
        sound: custom ? 'timer_$tone.wav' : null,
      ),
    );
  }

  /// Rings at [at] (even if the app is in the background or closed) with the chosen [tone].
  /// [sound] false = a silent notification.
  static Future<void> schedule(DateTime at, String title, String body,
      {String tone = 'chime', bool sound = true}) async {
    if (!_supported) return;
    try {
      await init();
      await _plugin.cancel(_id);
      final details = await _timerDetails(tone, sound);
      final when = tz.TZDateTime.from(at, tz.UTC);
      try {
        await _plugin.zonedSchedule(_id, title, body, when, details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
      } catch (_) {
        // exact alarms not allowed on this device: fall back to an inexact one
        await _plugin.zonedSchedule(_id, title, body, when, details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
      }
    } catch (_) {}
  }

  static Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _plugin.cancel(_id);
    } catch (_) {}
  }

  // ---------------------------------------------------------------- prayer + adhkar reminders

  // Prayer reminders use their own id range (7100..7159) so they never clash with the timer notification (7001).
  // Adhkar reminders use 7200..7229.
  static const _prayerBase = 7100;
  static const _prayerSlots = 60;
  static const _adhkarBase = 7200;
  static const _adhkarSlots = 30;

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

  static const _adhkarDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'adhkar_reminder',
      'Adhkar reminders',
      channelDescription: 'Morning and evening adhkar reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  /// Replaces every notification of one id range with [items] (only the ones still in the future).
  static Future<void> _replaceAll(int base, int slots, NotificationDetails details, List<PrayerAlert> items) async {
    if (!_supported) return;
    try {
      await init();
      for (var i = 0; i < slots; i++) {
        await _plugin.cancel(base + i);
      }
      final now = DateTime.now();
      var slot = 0;
      for (final a in items) {
        if (!a.at.isAfter(now)) continue;
        if (slot >= slots) break;
        final id = base + slot++;
        final when = tz.TZDateTime.from(a.at, tz.UTC);
        try {
          await _plugin.zonedSchedule(id, a.title, a.body, when, details,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
        } catch (_) {
          await _plugin.zonedSchedule(id, a.title, a.body, when, details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
        }
      }
    } catch (_) {}
  }

  static Future<void> _clearAll(int base, int slots) async {
    if (!_supported) return;
    try {
      for (var i = 0; i < slots; i++) {
        await _plugin.cancel(base + i);
      }
    } catch (_) {}
  }

  /// Replaces every scheduled prayer reminder with [items].
  static Future<void> schedulePrayers(List<PrayerAlert> items) =>
      _replaceAll(_prayerBase, _prayerSlots, _prayerDetails, items);

  static Future<void> clearPrayers() => _clearAll(_prayerBase, _prayerSlots);

  /// Replaces every scheduled morning / evening adhkar reminder with [items].
  static Future<void> scheduleAdhkar(List<PrayerAlert> items) =>
      _replaceAll(_adhkarBase, _adhkarSlots, _adhkarDetails, items);

  static Future<void> clearAdhkar() => _clearAll(_adhkarBase, _adhkarSlots);
}
