import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/notification_master.dart';

/// Schedules one repeating local notification/alarm per NotificationMaster
/// row with real-time, high-priority heads-up delivery and email alerts.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const String channelId = 'notification_master_channel';
  static const String channelName = 'Mone Rakho Realtime Notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Real-time reminders from your Mone Rakho list',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidImpl.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  /// Requests notification + exact-alarm permissions on Android 13+/12+.
  Future<void> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    try {
      await androidImpl.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
    try {
      await androidImpl.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Exact alarm permission error: $e');
    }
  }

  /// Triggers a notification immediately in real time, and sends email if specified.
  Future<void> showNotificationNow(NotificationMaster entry) async {
    final message = (entry.notification == null || entry.notification!.trim().isEmpty)
        ? 'Reminder'
        : entry.notification!;

    await _plugin.show(
      entry.notificationIntId,
      'Notification',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Real-time reminders from your Mone Rakho list',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      payload: entry.id,
    );

    if (entry.email != null && entry.email!.trim().isNotEmpty) {
      await sendEmail(entry);
    }
  }

  Future<String?> sendEmailWithResult(NotificationMaster entry) async {
    if (entry.email == null || entry.email!.trim().isEmpty) return 'No recipient email specified';
    try {
      final prefs = await SharedPreferences.getInstance();
      var senderEmail = prefs.getString('smtp_sender_email')?.trim() ?? '';
      var senderPassword = prefs.getString('smtp_app_password')?.trim() ?? '';

      if (senderEmail.isEmpty) {
        senderEmail = 'sulmak.mridha@gmail.com';
        await prefs.setString('smtp_sender_email', senderEmail);
      }
      if (senderPassword.isEmpty) {
        senderPassword = 'kvpg pilg hsdf ljf';
        await prefs.setString('smtp_app_password', senderPassword);
      }

      final recipient = entry.email!.trim();
      final subject = 'Mone Rakho Notification: ${entry.notification ?? "Reminder"}';
      final body = 'Hello,\n\nThis is your scheduled notification from Mone Rakho:\n\n"${entry.notification ?? "Reminder"}"\n\nDate: ${entry.notificationDate}\n\nPowered by Md. Atikur Rahman Mridha';

      final smtpServer = gmail(senderEmail, senderPassword);

      final message = mailer.Message()
        ..from = mailer.Address(senderEmail, 'Mone Rakho')
        ..recipients.add(recipient)
        ..subject = subject
        ..text = body;

      final sendReport = await mailer.send(message, smtpServer);
      debugPrint('Email sent successfully to $recipient: ${sendReport.toString()}');
      return null;
    } catch (e) {
      debugPrint('Error sending email notification via SMTP: $e');
      return e.toString();
    }
  }

  Future<bool> sendEmail(NotificationMaster entry) async {
    final err = await sendEmailWithResult(entry);
    if (err != null) {
      debugPrint('Email send failed: $err');
    }
    return err == null;
  }

  /// Schedules (or re-schedules) the alarm for a single entry, monthly or
  /// yearly depending on its repeatType.
  Future<void> scheduleEntry(NotificationMaster entry) async {
    if (entry.notificationDate == null) return;

    final message = (entry.notification == null || entry.notification!.trim().isEmpty)
        ? 'Reminder'
        : entry.notification!;

    final isYearly = entry.repeatType == RepeatType.yearly;
    final scheduledTime = nextOccurrenceFor(entry);
    debugPrint('Scheduling notification "${entry.id}" ($message) for $scheduledTime (repeat: ${entry.repeatType})');

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Real-time reminders from your Mone Rakho list',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    try {
      await _plugin.zonedSchedule(
        entry.notificationIntId,
        'Notification',
        message,
        scheduledTime,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            isYearly ? DateTimeComponents.dateAndTime : DateTimeComponents.dayOfMonthAndTime,
        payload: entry.id,
      );
      debugPrint('Successfully scheduled exact alarm for ${entry.id}');
    } catch (e) {
      debugPrint('Exact alarm scheduling failed for ${entry.id}: $e. Falling back to inexact...');
      try {
        await _plugin.zonedSchedule(
          entry.notificationIntId,
          'Notification',
          message,
          scheduledTime,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents:
              isYearly ? DateTimeComponents.dateAndTime : DateTimeComponents.dayOfMonthAndTime,
          payload: entry.id,
        );
        debugPrint('Successfully scheduled inexact alarm for ${entry.id}');
      } catch (e2) {
        debugPrint('Failed to schedule alarm for ${entry.id}: $e2');
      }
    }
  }

  /// Cancels the alarm for a single entry.
  Future<void> cancelEntry(NotificationMaster entry) =>
      _plugin.cancel(entry.notificationIntId);

  Future<void> cancelById(String id) =>
      _plugin.cancel(id.hashCode & 0x7FFFFFFF);

  /// Re-schedules every entry in [entries].
  Future<void> rescheduleAll(List<NotificationMaster> entries) async {
    for (final entry in entries) {
      await scheduleEntry(entry);
    }
  }

  /// Returns the next occurrence for this entry.
  tz.TZDateTime nextOccurrenceFor(NotificationMaster entry) {
    final date = entry.notificationDate ?? DateTime.now();
    return entry.repeatType == RepeatType.yearly
        ? _nextYearlyOccurrence(date)
        : _nextMonthlyOccurrence(date);
  }

  tz.TZDateTime _nextMonthlyOccurrence(DateTime notificationDate) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final day = notificationDate.day;
    final hour = notificationDate.hour;
    final minute = notificationDate.minute;

    tz.TZDateTime scheduled = _safeTzDateTime(now.year, now.month, day, hour, minute);

    if (scheduled.isBefore(now)) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      scheduled = _safeTzDateTime(nextYear, nextMonth, day, hour, minute);
    }
    return scheduled;
  }

  tz.TZDateTime _nextYearlyOccurrence(DateTime notificationDate) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final month = notificationDate.month;
    final day = notificationDate.day;
    final hour = notificationDate.hour;
    final minute = notificationDate.minute;

    tz.TZDateTime scheduled = _safeTzDateTime(now.year, month, day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = _safeTzDateTime(now.year + 1, month, day, hour, minute);
    }
    return scheduled;
  }

  tz.TZDateTime _safeTzDateTime(int year, int month, int day, int hour, int minute) {
    int lastDayOfMonth(int y, int m) => DateTime(y, m + 1, 0).day;
    final safeDay = day > lastDayOfMonth(year, month) ? lastDayOfMonth(year, month) : day;
    return tz.TZDateTime(tz.local, year, month, safeDay, hour, minute);
  }
}
