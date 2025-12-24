import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';
import '../services/reminder_notification.dart';
import '../utility/appbar.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

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

  //here we will load the data of pending notification i.e. notification for reminder which are yet to be marked as paid
  //by filtering it using due date of the reminder 
  Future<void> _loadPendingNotifications() async {
    setState(() => _isLoading = true);

    try {
      final remindersData =
          await DatabaseHelper.instance.billReminderDao.getAll();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final reminders =
          remindersData.where((r) {
              if (r.isPaid ?? false) return false;
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

      if (!mounted) return;
      setState(() {
        _items = reminders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack('Failed to load notifications', context, error: true);
    }
  }

  //here the bill reminder will be marked as paid
  //and if it is recurring then we will recalculte the next due date and make it again as unpaid
  //along with this we are calling notification service to have a scheduled notification for the reminder
  //if it is not a recurring reminder then the all notification for that bill will be cancelled
  Future<void> _markAsPaid(BillReminderModel r) async {
    if (r.id == null) {
      showSnack('Invalid reminder (missing id)', context, error: true);
      return;
    }

    //Update DB
    try {
      await DatabaseHelper.instance.billReminderDao.markBillAsPaid(r.id!, true);
    } catch (e) {
      if (!mounted) return;
      showSnack('Failed to update reminder status', context, error: true);
      return;
    }

    //Notifications 
    try {
      if (r.isRecurring == true) {
        // Fetch the latest reminder row from DB (important)
        final all = await DatabaseHelper.instance.billReminderDao.getAll();
        final updated = all.firstWhere((m) => m.id == r.id, orElse: () => r);

        // Pass context so user sees snack, and ensure service uses latest DB row
        await ReminderNotificationService.advanceRecurringAndReschedule(
          updated,
          context: context,
        );
      } else {
        await ReminderNotificationService.cancelReminderNotifications(
          r.id!,
          context: context,
        );
      }

      if (!mounted) return;
      showSnack(
        'Successfully updated reminder notifications',
        context,
        error: false,
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(
        'Failed to update reminder notifications',
        context,
        error: true,
      );
    }

    //Reload UI after marking the bill as paid to have fresh list of notification which are unpaid
    try {
      await _loadPendingNotifications();
      if (!mounted) return;
      showSnack('Marked as paid', context);
    } catch (e) {
      if (!mounted) return;
      showSnack('Marked as paid, but refresh failed', context, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    return Scaffold(
      appBar: Appbar(title: 'Notifications', isBackButton: true,),
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
                            kCategoryIcons[r.category] ??
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
                          Text('₹ ${r.amount.toStringAsFixed(2)}'),
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
