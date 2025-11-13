import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';

class ReminderNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _tzChannel = MethodChannel('app/timezone');

  // Initialize notifications, timezone, and permissions
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      final localTz =
          await _tzChannel.invokeMethod<String>('getLocalTimezone') ?? 'UTC';
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {}

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _requestPermissions();
    await _migratePastRecurringReminders();
  }

  static Future<void> _requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}
    try {
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {}
  }

  //handle Dismiss and Mark as Paid
  static void _onNotificationTap(NotificationResponse response) async {
    final payload = response.payload ?? '';
    final id = _parseReminderId(payload);
    if (id == null) return;

    if (response.actionId == 'mark_paid') {
      await DatabaseHelper.instance.markBillAsPaid(id, true);

      // Load the reminder to know if it is recurring
      final all = await DatabaseHelper.instance.getBillReminders();
      final map = all.cast<Map<String, dynamic>?>().firstWhere(
        (m) => m?['id'] == id,
        orElse: () => null,
      );
      if (map != null) {
        final r = BillReminderModel.fromMap(map);
        if (r.isRecurring) {
          await advanceRecurringAndReschedule(r);
        } else {
          await cancelReminderNotifications(id);
        }
      }
    } else if (response.actionId == 'dismiss') {
      final isToday = payload.endsWith('_today');
      final notifId = id * 10 + (isToday ? 1 : 0);
      await _notificationsPlugin.cancel(notifId);
    }
  }

  static int? _parseReminderId(String payload) {
    final parts = payload.split('_');
    if (parts.length >= 3 && parts[0] == 'reminder') {
      return int.tryParse(parts[1]);
    }
    return null;
  }

  //schedule notifications for a reminder.
  // - For recurring monthly reminders we create a recurring due-date notification (monthly at 00:00).
  // - If dueDay > 1, we also create a recurring "day-before" notification at 00:00 on (dueDay - 1).
  // - Non-recurring reminders are scheduled as one-off notifications.
  static Future<void> scheduleReminderNotifications(
    BillReminderModel reminder,
  ) async {
    final settings = await DatabaseHelper.instance.getSettings();
    if (settings['notifications'] != 'enabled') return;

    await cancelReminderNotifications(reminder.id!);

    final now = DateTime.now();
    final dueDate = DateTime(
      reminder.dueDate.year,
      reminder.dueDate.month,
      reminder.dueDate.day,
    );
    final dayBefore = dueDate.subtract(const Duration(days: 1));

    final scheduledDue = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      0,
      0,
    );
    final scheduledBefore = DateTime(
      dayBefore.year,
      dayBefore.month,
      dayBefore.day,
      0,
      0,
    );

    if (reminder.isRecurring) {
      await _scheduleNotification(
        id: reminder.id! * 10 + 1,
        title: '⚠️ Bill Due Today',
        body:
            '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due today!',
        scheduledDate: scheduledDue,
        payload: 'reminder_${reminder.id}_today',
        isRecurringMonthly: true,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );

      if (dueDate.day > 1) {
        await _scheduleNotification(
          id: reminder.id! * 10,
          title: '📋 Bill Due Tomorrow',
          body:
              '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due tomorrow',
          scheduledDate: scheduledBefore,
          payload: 'reminder_${reminder.id}_tomorrow',
          isRecurringMonthly: true,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      }
    } else {
      if (scheduledBefore.isAfter(now)) {
        await _scheduleNotification(
          id: reminder.id! * 10,
          title: '📋 Bill Due Tomorrow',
          body:
              '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due tomorrow',
          scheduledDate: scheduledBefore,
          payload: 'reminder_${reminder.id}_tomorrow',
        );
      }
      if (scheduledDue.isAfter(now)) {
        await _scheduleNotification(
          id: reminder.id! * 10 + 1,
          title: '⚠️ Bill Due Today',
          body:
              '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due today!',
          scheduledDate: scheduledDue,
          payload: 'reminder_${reminder.id}_today',
        );
      }
    }
  }

  // Internal helper: schedule a notification (zonedSchedule). If isRecurringMonthly is true
  // and a matchDateTimeComponents is provided, the notification will repeat monthly.
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool isRecurringMonthly = false,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Notifications for upcoming bill payments',
      importance: Importance.max,
      priority: Priority.max,
      autoCancel: true,
      actions: [
        const AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'mark_paid',
          'Mark as Paid',
          cancelNotification: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          isRecurringMonthly ? matchDateTimeComponents : null,
    );
  }

  static Future<void> cancelReminderNotifications(int reminderId) async {
    await _notificationsPlugin.cancel(reminderId * 10);
    await _notificationsPlugin.cancel(reminderId * 10 + 1);
  }

  // Called by initialize() to move any recurring reminders that are in the past
  // forward until their dueDate is >= today. This prevents recurring reminders
  // from remaining stuck in the past.
  static Future<void> _migratePastRecurringReminders() async {
    final reminders = await DatabaseHelper.instance.getBillReminders();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final map in reminders) {
      final r = BillReminderModel.fromMap(map);
      if (!r.isRecurring) continue;

      DateTime due = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
      bool advanced = false;
      while (due.isBefore(today)) {
        due = _addMonthsSafe(due, 1);
        advanced = true;
      }

      if (advanced) {
        await DatabaseHelper.instance.advanceRecurringReminder(r.id!, due);
        final updated = r.copyWith(dueDate: due, isPaid: false);
        await cancelReminderNotifications(r.id!);
        await scheduleReminderNotifications(updated);
      } else {
        await scheduleReminderNotifications(r);
      }
    }
  }

  // Safely add months handling month-end rollover
  static DateTime _addMonthsSafe(DateTime base, int months) {
    final y = base.year;
    final m = base.month + months;
    final targetYear = y + ((m - 1) ~/ 12);
    final targetMonth = ((m - 1) % 12) + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = base.day.clamp(1, lastDay);
    return DateTime(targetYear, targetMonth, day);
  }

  // Called when a reminder is marked as paid: advance to next occurrence and reschedule
  static Future<void> advanceRecurringAndReschedule(
    BillReminderModel reminder,
  ) async {
    final next = _addMonthsSafe(reminder.dueDate, 1);
    await DatabaseHelper.instance.advanceRecurringReminder(reminder.id!, next);
    final advanced = reminder.copyWith(dueDate: next, isPaid: false);
    await cancelReminderNotifications(reminder.id!);
    await scheduleReminderNotifications(advanced);
  }

  // Used for showing badge count (today/tomorrow)
  static Future<int> getTodayTomorrowPendingCount() async {
    final settings = await DatabaseHelper.instance.getSettings();
    if (settings['notifications'] != 'enabled') return 0;

    final data = await DatabaseHelper.instance.getBillReminders();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int count = 0;

    for (final m in data) {
      final r = BillReminderModel.fromMap(m);
      if (r.isPaid) continue;

      final due = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
      final diff = due.difference(today).inDays;

      if (diff == 0 || diff == 1) count++;
    }
    return count;
  }
}
