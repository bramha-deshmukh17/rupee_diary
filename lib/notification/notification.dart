import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';
import '../services/reminder_notification.dart';
import '../utility/constant.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});
  static const String id = '/notifications';

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<BillReminderModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingNotifications();
  }

  Future<void> _loadPendingNotifications() async {
    setState(() => _isLoading = true);

    final pendingIds =
        await ReminderNotificationService.getPendingNotificationIds();
    debugPrint('NotificationCenter: pendingIds=$pendingIds');

    final remindersData = await DatabaseHelper().getBillReminders();
    debugPrint(
      'NotificationCenter: total reminders in DB=${remindersData.length}',
    );

    final now = DateTime.now();

    final reminders =
        remindersData.map((m) => BillReminderModel.fromMap(m)).where((r) {
          if (r.isPaid) return false;
          final dayBeforeId = r.id! * 10;
          final todayId = r.id! * 10 + 1;
          final daysDiff = r.dueDate.difference(now).inDays;

          final hasPendingNotification =
              pendingIds.contains(dayBeforeId) || pendingIds.contains(todayId);
          final dueSoonOrToday = daysDiff == 0 || daysDiff == 1;
          final overdue = daysDiff < 0;

          // Include reminders that have pending/active notifications, or are due today/tomorrow, or are overdue
          return hasPendingNotification || dueSoonOrToday || overdue;
        }).toList();

    debugPrint('NotificationCenter: reminders to show=${reminders.length}');

    setState(() {
      _items = reminders;
      _isLoading = false;
    });
  }

  Future<void> _markAsPaid(BillReminderModel r) async {
    await DatabaseHelper().markBillAsPaid(r.id!, true);
    await ReminderNotificationService.cancelReminderNotifications(r.id!);
    await _loadPendingNotifications();
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body:
          _items.isEmpty
              ? Center(
                child: Text(
                  'No pending notifications',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final r = _items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(r.title),
                      subtitle: Text(
                        'Due: ${r.dueDate.toLocal().toIso8601String().split('T')[0]} • ₹${r.amount.toStringAsFixed(2)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _markAsPaid(r),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                            ),
                            child: const Text('Mark as Paid'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
