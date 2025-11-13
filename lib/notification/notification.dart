import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  static const Map<String, IconData> _categoryIcons = {
    'Utilities': FontAwesomeIcons.receipt,
    'Rent/Mortgage': FontAwesomeIcons.house,
    'Insurance': FontAwesomeIcons.shieldHalved,
    'Phone/Internet': FontAwesomeIcons.wifi,
    'Subscription': FontAwesomeIcons.repeat,
    'Loan Payment': FontAwesomeIcons.landmark,
    'Credit Card': FontAwesomeIcons.creditCard,
    'Other': FontAwesomeIcons.shapes,
  };

  @override
  void initState() {
    super.initState();
    _loadPendingNotifications();
  }

  Future<void> _loadPendingNotifications() async {
    setState(() => _isLoading = true);

    try {
      final remindersData = await DatabaseHelper.instance.getBillReminders();
      debugPrint(
        'NotificationCenter: total reminders in DB=${remindersData.length}',
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final reminders =
          remindersData.map((m) => BillReminderModel.fromMap(m)).where((r) {
              if (r.isPaid) return false;
              final due = DateTime(
                r.dueDate.year,
                r.dueDate.month,
                r.dueDate.day,
              );
              final daysDiff = due.difference(today).inDays;
              // Only today or tomorrow
              return daysDiff == 0 || daysDiff == 1;
            }).toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      setState(() {
        _items = reminders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('NotificationCenter: error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsPaid(BillReminderModel r) async {
    await DatabaseHelper.instance.markBillAsPaid(r.id!, true);
    if (r.isRecurring) {
      // Advance recurring reminder automatically and reschedule notifications
      await ReminderNotificationService.advanceRecurringAndReschedule(r);
    } else {
      // Cancel any scheduled notifications for non-recurring reminders
      await ReminderNotificationService.cancelReminderNotifications(r.id!);
    }
    await _loadPendingNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
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
                  style: textTheme.headlineMedium,
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
                      title: Row(
                        children: [
                          Icon(
                            _categoryIcons[r.category] ??
                                FontAwesomeIcons.shapes,
                            size: 20,
                            color: kPrimaryColor,
                          ),
                          kwBox,
                          Expanded(
                            child: Text(
                              r.title,
                              style: textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Due: ${r.dueDate.toLocal().toIso8601String().split('T')[0]}',
                            style: textTheme.bodyMedium?.copyWith(color: kRed),
                          ),
                          Text('₹${r.amount.toStringAsFixed(2)}'),
                        ],
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
                            child: Text(
                              'Mark as Paid',
                              style: textTheme.bodyLarge?.copyWith(
                                color: kWhite,
                              ),
                            ),
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
