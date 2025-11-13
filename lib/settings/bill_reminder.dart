import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';
import '../utility/appbar.dart';
import '../utility/constant.dart';
import '../services/reminder_notification.dart';
import 'edit_add_reminder.dart';

class BillReminder extends StatefulWidget {
  const BillReminder({super.key});
  static const String id = "/settings/reminder";

  @override
  State<BillReminder> createState() => _BillReminderState();
}

class _BillReminderState extends State<BillReminder> {
  List<BillReminderModel> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final reminders = await DatabaseHelper.instance.getBillReminders();
    setState(() {
      _reminders = reminders.map((r) => BillReminderModel.fromMap(r)).toList();
      _isLoading = false;
    });
  }

  Future<void> _deleteReminder(BillReminderModel reminder) async {
    // Cancel notifications before deleting
    await ReminderNotificationService.cancelReminderNotifications(reminder.id!);
    await DatabaseHelper.instance.deleteBillReminder(reminder.id!);
    _loadReminders();
  }

  void _showAddEditDialog([BillReminderModel? reminder]) {
    showDialog(
      context: context,
      builder:
          (context) => AddEditReminderDialog(
            reminder: reminder,
            onSave: () {
              _loadReminders();
            },
          ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    // Add the missing loading check
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    return Scaffold(
      appBar: const Appbar(title: "Bill Reminders"),
      body:
          _reminders.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reminders.length,
                itemBuilder: (context, index) {
                  final reminder = _reminders[index];
                  return _buildReminderCard(reminder);
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: kWhite),
      ),
    );
  }

  Widget _buildEmptyState() {
    final textTheme = TextTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.fileInvoice, size: 64, color: kGrey),
          khBox,
          Text(
            'No Bill Reminders',
            style: textTheme.displayLarge?.copyWith(
              color: kGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
          khBox,
          Text(
            'Add your first bill reminder to get started',
            style: textTheme.displayLarge?.copyWith(
              color: kGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BillReminderModel reminder) {
    // Category icon mapping
    final Map<String, IconData> _categoryIcons = {
      'Utilities': FontAwesomeIcons.receipt,
      'Rent/Mortgage': FontAwesomeIcons.house,
      'Insurance': FontAwesomeIcons.shieldHalved,
      'Phone/Internet': FontAwesomeIcons.wifi,
      'Subscription': FontAwesomeIcons.repeat,
      'Loan Payment': FontAwesomeIcons.landmark,
      'Credit Card': FontAwesomeIcons.creditCard,
      'Other': FontAwesomeIcons.shapes,
    };

    final iconData = _categoryIcons[reminder.category] ?? Icons.category;
    final textTheme = TextTheme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kPrimaryColor.withOpacity(0.1),
          child: Icon(iconData, color: kPrimaryColor, size: 18),
        ),
        title: Text(reminder.title, style: TextTheme.of(context).bodyLarge),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹${reminder.amount.toStringAsFixed(2)}',
              style: textTheme.bodyMedium?.copyWith(color: kRed),
            ),
            Text(
              'Due: ${_formatDate(reminder.dueDate)}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                _showAddEditDialog(reminder);
                break;
              case 'delete':
                _deleteReminder(reminder);
                break;
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [Icon(Icons.edit, size: 18), kwBox, Text('Edit')],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: kRed),
                      kwBox,
                      Text('Delete', style: TextStyle(color: kRed)),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }
}
