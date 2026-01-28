import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';
import '../notification/notification.dart';
import '../utility/snack.dart';
import 'route_observer.dart';

// Service to manage reminder notifications
class ReminderNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const MethodChannel _tzChannel = MethodChannel('app/timezone');

  static int kReminderHour = 09; // 9 AM
  static int kReminderMinute = 00; // 0 Minutes

  // Initialize timezone, notification plugin, permissions, and migrate reminders.
  // If [context] is provided, permission-related snackbars will be shown.
  static Future<void> initialize([BuildContext? context]) async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final localTz =
          await _tzChannel.invokeMethod<String>('getLocalTimezone') ?? 'UTC';
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (e) {
      debugPrint('ReminderNotificationService: timezone init failed: $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'bill_reminder_actions',
          actions: [
            DarwinNotificationAction.plain('dismiss', 'Dismiss'),
            DarwinNotificationAction.plain('mark_paid', 'Mark as Paid'),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _requestPermissions(context);
    // migrate reminders but tell scheduling to skip re-initialization to avoid loops
    await _migratePastRecurringReminders(context);

    _initialized = true;
  }

  // Reads notification setting from DB.
  static Future<bool> _notificationsEnabled() async {
    try {
      final settings = await DatabaseHelper.instance.settingDao.getSettings();
      final map = <String, String>{
        for (final s in settings)
          if ((s.settingsKey ?? '').isNotEmpty &&
              (s.settingsValue ?? '').isNotEmpty)
            s.settingsKey!: s.settingsValue!,
      };
      // default to enabled if missing
      final enabled = (map['notifications'] ?? 'enabled') == 'enabled';
      return enabled;
    } catch (e) {
      return true;
    }
  }

  // Request permissions show error snack if denied
  static Future<void> _requestPermissions(BuildContext? context) async {
    try {
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        if (!status.isGranted && context != null) {
          showSnack('Notification permission denied', context, error: true);
        }
      }
    } catch (e) {
      debugPrint(
        'ReminderNotificationService: permission (notification) error: $e',
      );
    }
  }

  // Handle notification action taps (mark paid / dismiss).
  static void _onNotificationTap(NotificationResponse response) async {
    final payload = response.payload ?? '';
    final id = _parseReminderId(payload);
    if (id == null) return;

    if (response.actionId == 'mark_paid') {
      // Mark paid in DB
      await DatabaseHelper.instance.billReminderDao.markBillAsPaid(id, true);

      // Load the reminder from DB to get current fields
      final all = await DatabaseHelper.instance.billReminderDao.getAll();
      final r = all.firstWhere(
        (m) => m.id == id,
        orElse:
            () => BillReminderModel(
              id: id,
              title: '',
              amount: 0,
              dueDate: DateTime.now(),
              categoryId: null,
            ),
      );

      if (r.title.isNotEmpty && r.isRecurring == true) {
        await advanceRecurringAndReschedule(r);
      } else {
        await cancelReminderNotifications(id);
      }
    } else if (response.actionId == 'dismiss') {
      final isToday = payload.endsWith('_today');
      final notifId = id * 10 + (isToday ? 1 : 0);
      await _notificationsPlugin.cancel(notifId);
    } else {
      // open NotificationCenterScreen using global navigator key
      // guard in case app isn't yet ready
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushNamed(NotificationCenterScreen.id);
      } else {
        // fallback: try to get a context and use Navigator
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          Navigator.of(ctx).pushNamed(NotificationCenterScreen.id);
        }
      }
    }
  }

  static int? _parseReminderId(String payload) {
    final parts = payload.split('_');
    if (parts.length >= 3 && parts[0] == 'reminder') {
      return int.tryParse(parts[1]);
    }
    return null;
  }

  // Schedule notifications for a reminder.
  // If [context] is provided, a success / error SnackBar will be shown.
  // If [skipInitialize] is true, this function will NOT call initialize() (useful during migration).
  static Future<void> scheduleReminderNotifications(
    BillReminderModel reminder, {
    BuildContext? context,
    bool skipInitialize = false,
  }) async {
    if (!skipInitialize) {
      await initialize(context);
    }

    if (!(await _notificationsEnabled())) {
      if (context != null) {
        showSnack('Notifications disabled in settings', context, error: true);
      }
      return;
    }

    if (reminder.id == null) {
      if (context != null) {
        showSnack('Invalid reminder id', context, error: true);
      }
      return;
    }

    await cancelReminderNotifications(reminder.id!, context: context);

    final now = DateTime.now();
    final dueDate = DateTime(
      reminder.dueDate.year,
      reminder.dueDate.month,
      reminder.dueDate.day,
    );
    final dayBefore = dueDate.subtract(const Duration(days: 1));

    final dueAt = _atReminderTime(dueDate);
    final beforeAt = _atReminderTime(dayBefore);

    try {
      if (reminder.isRecurring ?? false) {
        // Due day notification (recurring monthly)
        await _schedule(
          id: reminder.id! * 10 + 1,
          title: 'Bill Due Today',
          body:
              '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due today!',
          scheduled: dueAt,
          payload: 'reminder_${reminder.id}_today',
          recurring: true,
        );

        // Day-before recurring (skip if due is 1st)
        if (dueDate.day > 1) {
          await _schedule(
            id: reminder.id! * 10,
            title: 'Bill Due Tomorrow',
            body:
                '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due tomorrow',
            scheduled: beforeAt,
            payload: 'reminder_${reminder.id}_tomorrow',
            recurring: true,
          );
        }

        // Optional catch-up: if due is today and time passed, fire a one-shot soon
        if (DateTime(now.year, now.month, now.day) == dueDate &&
            dueAt.isBefore(now)) {
          await _schedule(
            id:
                reminder.id! * 10 +
                1, // same id replaces any previous pending instance
            title: 'Bill Due Today',
            body:
                '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due today!',
            scheduled: now.add(const Duration(minutes: 1)),
            payload: 'reminder_${reminder.id}_today',
          );
        }
      } else {
        // One-time reminders: only schedule future notifications
        if (beforeAt.isAfter(now)) {
          await _schedule(
            id: reminder.id! * 10,
            title: 'Bill Due Tomorrow',
            body:
                '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due tomorrow',
            scheduled: beforeAt,
            payload: 'reminder_${reminder.id}_tomorrow',
          );
        }
        if (dueAt.isAfter(now)) {
          await _schedule(
            id: reminder.id! * 10 + 1,
            title: 'Bill Due Today',
            body:
                '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due today!',
            scheduled: dueAt,
            payload: 'reminder_${reminder.id}_today',
          );
        } else if (DateTime(now.year, now.month, now.day) == dueDate) {
          // catch-up: schedule in a minute if due is today and time already passed
          await _schedule(
            id: reminder.id! * 10 + 1,
            title: 'Bill Due Today',
            body:
                '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due today!',
            scheduled: now.add(const Duration(minutes: 1)),
            payload: 'reminder_${reminder.id}_today',
          );
        }
      }

      if (context != null) {
        showSnack('Reminder scheduled successfully', context);
      }
    } catch (e) {
      if (context != null) {
        showSnack('Failed to schedule reminder: $e', context, error: true);
      }
    }
  }

  // helper: clamp a date to the preferred reminder time
  static DateTime _atReminderTime(DateTime d) =>
      DateTime(d.year, d.month, d.day, kReminderHour, kReminderMinute);

  // Internal scheduler wrapper.
  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduled,
    String? payload,
    bool recurring = false,
  }) async {
    final android = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Notifications for upcoming bills',
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

    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'bill_reminder_actions', // link iOS actions
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduled, tz.local),
      NotificationDetails(android: android, iOS: ios),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          recurring ? DateTimeComponents.dayOfMonthAndTime : null,
    );
  }

  // Cancel notifications for a reminder.
  static Future<void> cancelReminderNotifications(
    int id, {
    BuildContext? context,
  }) async {
    await _notificationsPlugin.cancel(id * 10);
    await _notificationsPlugin.cancel(id * 10 + 1);

    if (context != null) showSnack('Existing notifications cleared', context);
  }

  // Move past recurring reminders forward and reschedule.
  // Uses scheduleReminderNotifications(..., skipInitialize: true) to avoid reinitialization loop.
  // if anyonw recurring reminder is failed to mark as paid it will automatically catch up here
  static Future<void> _migratePastRecurringReminders(
    BuildContext? context,
  ) async {
    final reminders = await DatabaseHelper.instance.billReminderDao.getAll();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final r in reminders) {
      if (!(r.isRecurring ?? false)) continue;

      DateTime due = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
      bool advanced = false;

      while (due.isBefore(today)) {
        due = _addMonthsSafe(due, 1);
        advanced = true;
      }

      if (advanced) {
        await DatabaseHelper.instance.billReminderDao.advanceRecurringReminder(
          r.id!,
          due,
        );
        final updated = r.copyWith(dueDate: due, isPaid: false);
        await cancelReminderNotifications(r.id!, context: context);
        // skipInitialize true because we are already inside initialize
        await scheduleReminderNotifications(
          updated,
          context: context,
          skipInitialize: true,
        );

        if (context != null) {
          showSnack('Recurring reminder updated automatically', context);
        }
      } else {
        await scheduleReminderNotifications(
          r,
          context: context,
          skipInitialize: true,
        );
      }
    }
  }

  static DateTime _addMonthsSafe(DateTime base, int months) {
    final targetYear = base.year + ((base.month + months - 1) ~/ 12);
    final targetMonth = ((base.month + months - 1) % 12) + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    return DateTime(targetYear, targetMonth, base.day.clamp(1, lastDay));
  }

  // Advance a recurring reminder after marking paid and reschedule next occurrence.
  static Future<void> advanceRecurringAndReschedule(
    BillReminderModel reminder, {
    BuildContext? context,
  }) async {
    try {
      // Ensure initialized
      await initialize(context);

      if (!(await _notificationsEnabled())) {
        if (context != null) {
          showSnack('Notifications disabled in settings', context, error: true);
        }
        return;
      }

      if (reminder.id == null) {
        if (context != null) {
          showSnack('Invalid reminder', context, error: true);
        }
        return;
      }

      // Compute next due date
      final base = DateTime(
        reminder.dueDate.year,
        reminder.dueDate.month,
        reminder.dueDate.day,
      );
      final nextDate = _addMonthsSafe(base, 1);

      // Update DB (advance the stored due date)
      await DatabaseHelper.instance.billReminderDao.advanceRecurringReminder(
        reminder.id!,
        nextDate,
      );

      // Re-load the updated reminder from DB to ensure latest data
      final all = await DatabaseHelper.instance.billReminderDao.getAll();
      final updatedReminder = all.firstWhere(
        (m) => m.id == reminder.id,
        orElse: () => reminder.copyWith(dueDate: nextDate, isPaid: false),
      );

      // Cancel old notifications and schedule new ones using updated model
      await cancelReminderNotifications(reminder.id!, context: context);
      await scheduleReminderNotifications(updatedReminder, context: context);

      if (context != null) {
        final d = nextDate.toLocal().toIso8601String().split('T').first;
        showSnack('Rescheduled for $d', context);
      }
    } catch (e) {
      if (context != null) {
        showSnack(
          'Failed to reschedule recurring reminder',
          context,
          error: true,
        );
      }
    }
  }

  // Count pending reminders for today/tomorrow
  static Future<int> getTodayTomorrowPendingCount() async {
    if (!(await _notificationsEnabled())) return 0;

    final data = await DatabaseHelper.instance.billReminderDao.getAll();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return data.where((r) {
      if (r.isPaid == true) return false;
      final due = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
      final diff = due.difference(today).inDays;
      return diff == 0 || diff == 1;
    }).length;
  }
}
