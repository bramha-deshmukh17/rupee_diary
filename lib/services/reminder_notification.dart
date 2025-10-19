import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';

class ReminderNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

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
  }

  static Future<void> _requestPermissions() async {
    await Permission.notification.isDenied.then((value) {
      if (value) {
        Permission.notification.request();
      }
    });

    // Request exact alarm permission for Android 12+
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  static void _onNotificationTap(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload != null) {
      // Handle notification tap - you can navigate to bill details
      print('Notification tapped with payload: $payload');
    }
  }

  static Future<void> scheduleReminderNotifications(
    BillReminderModel reminder,
  ) async {
    final settings = await DatabaseHelper().getSettings();
    final notificationsEnabled = settings['notifications'] == 'enabled';

    if (!notificationsEnabled) return;

    final now = DateTime.now();
    // Normalize reminder date to date-only
    final dueDate = DateTime(
      reminder.dueDate.year,
      reminder.dueDate.month,
      reminder.dueDate.day,
    );
    final dayBeforeDate = dueDate.subtract(const Duration(days: 1));

    // Schedule at 9:00 local time for both notifications
    final scheduledDayBefore = DateTime(
      dayBeforeDate.year,
      dayBeforeDate.month,
      dayBeforeDate.day,
      9,
    );
    final scheduledDueDate = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9,
    );

    if (scheduledDayBefore.isAfter(now)) {
      await _scheduleNotification(
        id: reminder.id! * 10,
        title: '📋 Bill Due Tomorrow',
        body:
            '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due tomorrow',
        scheduledDate: scheduledDayBefore,
        payload: 'reminder_${reminder.id}_tomorrow',
        isHighPriority: true,
      );
    }

    if (scheduledDueDate.isAfter(now)) {
      await _scheduleNotification(
        id: reminder.id! * 10 + 1,
        title: '⚠️ Bill Due Today',
        body:
            '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due today!',
        scheduledDate: scheduledDueDate,
        payload: 'reminder_${reminder.id}_today',
        isHighPriority: true,
      );
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool isHighPriority = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Notifications for upcoming bill payments',
      importance: isHighPriority ? Importance.max : Importance.high,
      priority: isHighPriority ? Priority.max : Priority.high,
      ongoing: isHighPriority, // Makes notification non-dismissible
      autoCancel: !isHighPriority, // Prevents auto-dismiss for high priority
      showWhen: true,
      when: scheduledDate.millisecondsSinceEpoch,
      actions:
          isHighPriority
              ? [
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
              ]
              : null,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

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
    );
  }

  static Future<void> cancelReminderNotifications(int reminderId) async {
    // Cancel both notifications (day before and due date)
    await _notificationsPlugin.cancel(reminderId * 10);
    await _notificationsPlugin.cancel(reminderId * 10 + 1);
  }

  static Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isHighPriority = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Notifications for upcoming bill payments',
      importance: isHighPriority ? Importance.max : Importance.high,
      priority: isHighPriority ? Priority.max : Priority.high,
      ongoing: isHighPriority,
      autoCancel: !isHighPriority,
      actions:
          isHighPriority
              ? [
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
              ]
              : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  static Future<void> dismissNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  static Future<void> checkAndShowDueNotifications() async {
    final settings = await DatabaseHelper().getSettings();
    final notificationsEnabled = settings['notifications'] == 'enabled';
    if (!notificationsEnabled) return;

    final reminders = await DatabaseHelper().getBillReminders();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final reminderMap in reminders) {
      final reminder = BillReminderModel.fromMap(reminderMap);
      if (reminder.isPaid) continue;

      final dueDate = DateTime(
        reminder.dueDate.year,
        reminder.dueDate.month,
        reminder.dueDate.day,
      );
      final daysDifference = dueDate.difference(today).inDays;

      if (daysDifference == 1) {
        await showImmediateNotification(
          id: reminder.id! * 10,
          title: '📋 Bill Due Tomorrow',
          body:
              '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due tomorrow',
          payload: 'reminder_${reminder.id}_tomorrow',
          isHighPriority: true,
        );
      } else if (daysDifference == 0) {
        await showImmediateNotification(
          id: reminder.id! * 10 + 1,
          title: '⚠️ Bill Due Today',
          body:
              '${reminder.title} (₹${reminder.amount.toStringAsFixed(2)}) is due today!',
          payload: 'reminder_${reminder.id}_today',
          isHighPriority: true,
        );
      }
    }
  }

  static Future<Set<int>> getPendingNotificationIds() async {
    final ids = <int>{};

    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final p in pending) {
        ids.add(p.id);
      }
    } catch (e) {
      // ignore
    }

    // On Android, also include currently active (displayed) notifications
    try {
      final androidImpl =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidImpl != null) {
        final active = await androidImpl.getActiveNotifications();
        for (final a in active) {
          if (a.id != null) ids.add(a.id!);
        }
      }
    } catch (e) {
      // ignore
    }

    return ids;
  }
}
