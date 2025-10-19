import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';
import '../utility/appbar.dart';
import '../utility/constant.dart';
import '../services/reminder_notification.dart';

class BillReminder extends StatefulWidget {
  const BillReminder({super.key});
  static const String id = "/settings/reminder";

  @override
  State<BillReminder> createState() => _BillReminderState();
}

class _BillReminderState extends State<BillReminder> {
  List<BillReminderModel> _reminders = [];
  bool _isLoading = true;

  // Helper: compute days difference using date-only (ignore time-of-day)
  int _daysUntilDate(DateTime date) {
    final now = DateTime.now();
    final d1 = DateTime(date.year, date.month, date.day);
    final d2 = DateTime(now.year, now.month, now.day);
    return d1.difference(d2).inDays;
  }

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final reminders = await DatabaseHelper().getBillReminders();
    setState(() {
      _reminders = reminders.map((r) => BillReminderModel.fromMap(r)).toList();
      _isLoading = false;
    });
  }

  Future<void> _deleteReminder(BillReminderModel reminder) async {
    // Cancel notifications before deleting
    await ReminderNotificationService.cancelReminderNotifications(reminder.id!);
    await DatabaseHelper().deleteBillReminder(reminder.id!);
    _loadReminders();
  }

  // Mark a previously paid reminder as unpaid and reschedule notifications if appropriate
  Future<void> _markAsUnpaid(BillReminderModel reminder) async {
    try {
      await DatabaseHelper().markBillAsPaid(reminder.id!, false);
      // Ensure no duplicate schedules
      await ReminderNotificationService.cancelReminderNotifications(
        reminder.id!,
      );

      // Reschedule future notifications (will no-op if notifications disabled)
      final updated = reminder.copyWith(isPaid: false);
      await ReminderNotificationService.scheduleReminderNotifications(updated);

      // If due today/tomorrow, show an immediate notification so user sees it
      final daysUntilDue = _daysUntilDate(updated.dueDate);
      if (daysUntilDue == 1) {
        try {
          await ReminderNotificationService.showImmediateNotification(
            id: updated.id! * 10,
            title: '📋 Bill Due Tomorrow',
            body:
                '${updated.title} (₹${updated.amount.toStringAsFixed(2)}) is due tomorrow',
            payload: 'reminder_${updated.id}_tomorrow',
            isHighPriority: true,
          );
        } catch (_) {}
      } else if (daysUntilDue == 0) {
        try {
          await ReminderNotificationService.showImmediateNotification(
            id: updated.id! * 10 + 1,
            title: '⚠️ Bill Due Today',
            body:
                '${updated.title} (₹${updated.amount.toStringAsFixed(2)}) is due today!',
            payload: 'reminder_${updated.id}_today',
            isHighPriority: true,
          );
        } catch (_) {}
      }
    } catch (e) {
      // ignore errors
    }

    await _loadReminders();
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
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.fileInvoice,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No Bill Reminders',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first bill reminder to get started',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BillReminderModel reminder) {
    final daysUntilDue = _daysUntilDate(reminder.dueDate);
    final isOverdue = daysUntilDue < 0;
    final isDueSoon = daysUntilDue <= 5 && daysUntilDue >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              reminder.isPaid
                  ? Colors.green.withOpacity(0.1)
                  : isOverdue
                  ? Colors.red.withOpacity(0.1)
                  : isDueSoon
                  ? Colors.orange.withOpacity(0.1)
                  : kPrimaryColor.withOpacity(0.1),
          child: Icon(
            reminder.isPaid
                ? Icons.check
                : isOverdue
                ? Icons.warning
                : FontAwesomeIcons.fileInvoice,
            color:
                reminder.isPaid
                    ? Colors.green
                    : isOverdue
                    ? Colors.red
                    : isDueSoon
                    ? Colors.orange
                    : kPrimaryColor,
            size: 18,
          ),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: reminder.isPaid ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹${reminder.amount.toStringAsFixed(2)} • ${reminder.category}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              'Due: ${_formatDate(reminder.dueDate)}',
              style: TextStyle(
                color: isOverdue && !reminder.isPaid ? Colors.red : Colors.grey[600],
                fontWeight: isOverdue && !reminder.isPaid ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isOverdue && !reminder.isPaid)
              if(daysUntilDue==-1)
              Text(
                  'Overdue by a day',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              else if(daysUntilDue<-1)
              Text(
                  'Overdue by ${(-daysUntilDue)} days',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
            else if (isDueSoon && !reminder.isPaid)
              
                if (daysUntilDue == 0) 
                  Text(
                    'Due today',
                    style: const TextStyle(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  )
                else if (daysUntilDue == 1)
                  Text(
                    'Due tomorrow',
                    style: const TextStyle(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  )
                
                else if (daysUntilDue > 1)
                  Text(
                    'Due in $daysUntilDue days',
                    style: const TextStyle(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  )
              
            else if (reminder.isPaid)
              const Text(
                'Paid',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'mark_unpaid':
                await _markAsUnpaid(reminder);
                break;
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
                if (reminder.isPaid)
                  PopupMenuItem(
                    value: 'mark_unpaid',
                    child: Row(
                      children: const [
                        Icon(Icons.undo, size: 18),
                        SizedBox(width: 8),
                        Text('Mark as Unpaid'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }
}

class AddEditReminderDialog extends StatefulWidget {
  final BillReminderModel? reminder;
  final VoidCallback onSave;

  const AddEditReminderDialog({super.key, this.reminder, required this.onSave});

  @override
  State<AddEditReminderDialog> createState() => _AddEditReminderDialogState();
}

class _AddEditReminderDialogState extends State<AddEditReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Utilities';
  bool _isRecurring = false;
  String? _recurrenceType;

  final List<String> _categories = [
    'Utilities',
    'Rent/Mortgage',
    'Insurance',
    'Phone/Internet',
    'Subscription',
    'Loan Payment',
    'Credit Card',
    'Other',
  ];

  final List<String> _recurrenceTypes = [
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      _amountController.text = widget.reminder!.amount.toString();
      _notesController.text = widget.reminder!.notes ?? '';
      _selectedDate = widget.reminder!.dueDate;
      _selectedCategory = widget.reminder!.category;
      _isRecurring = widget.reminder!.isRecurring;
      _recurrenceType = widget.reminder!.recurrenceType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reminder == null
                      ? 'Add Bill Reminder'
                      : 'Edit Bill Reminder',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Bill Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: '₹',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: _selectedDate,
                      lastDate: DateTime.now().add(
                        const Duration(days: 365),
                      ),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Due Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                        ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                CheckboxListTile(
                  title: const Text('Recurring Bill'),
                  value: _isRecurring,
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value!;
                      if (!_isRecurring) {
                        _recurrenceType = null;
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                if (_isRecurring)
                  DropdownButtonFormField<String>(
                    value: _recurrenceType,
                    decoration: const InputDecoration(
                      labelText: 'Recurrence',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _recurrenceTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _recurrenceType = value;
                      });
                    },
                    validator: (value) {
                      if (_isRecurring && (value == null || value.isEmpty)) {
                        return 'Please select recurrence type';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveReminder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(widget.reminder == null ? 'Add' : 'Update'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveReminder() async {
    if (_formKey.currentState!.validate()) {
      final reminder = BillReminderModel(
        id: widget.reminder?.id,
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        dueDate: _selectedDate,
        category: _selectedCategory,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        isRecurring: _isRecurring,
        recurrenceType: _recurrenceType,
        isPaid: widget.reminder?.isPaid ?? false,
      );

      int reminderId;
      if (widget.reminder == null) {
        // Create new reminder
        reminderId = await DatabaseHelper().insertBillReminder(
          reminder.toMap(),
        );
        final newReminder = reminder.copyWith(id: reminderId);

        // Schedule notifications for new reminder
        await ReminderNotificationService.scheduleReminderNotifications(
          newReminder,
        );
      } else {
        // Update existing reminder
        reminderId = widget.reminder!.id!;
        await DatabaseHelper().updateBillReminder(reminderId, reminder.toMap());

        // Cancel old notifications and schedule new ones
        await ReminderNotificationService.cancelReminderNotifications(
          reminderId,
        );
        final updatedReminder = reminder.copyWith(id: reminderId);
        await ReminderNotificationService.scheduleReminderNotifications(
          updatedReminder,
        );
      }

      widget.onSave();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
