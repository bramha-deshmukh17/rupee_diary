import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';
import '../services/reminder_notification.dart';
import '../utility/constant.dart';

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                  style: textTheme.headlineSmall,
                ),
                khBox,
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Bill Title*',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter a title';
                    return null;
                  },
                ),
                khBox,
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount*',
                    border: OutlineInputBorder(),
                    prefixText: '₹',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter an amount';
                    if (double.tryParse(value) == null)
                      return 'Please enter a valid number';
                    return null;
                  },
                ),
                khBox,
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(_categoryIcons[_selectedCategory]),
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
                khBox,
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: _selectedDate,
                      lastDate: DateTime.now().add(const Duration(days: 31)),
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
                khBox,
                CheckboxListTile(
                  title: const Text('Monthly Recurring Bill'),
                  value: _isRecurring,
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                khBox,
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
        recurrenceType: _isRecurring ? 'Monthly' : null,
        isPaid: widget.reminder?.isPaid ?? false,
      );

      int reminderId;
      if (widget.reminder == null) {
        reminderId = await DatabaseHelper.instance.insertBillReminder(
          reminder.toMap(),
        );
        final newReminder = reminder.copyWith(id: reminderId);
        await ReminderNotificationService.scheduleReminderNotifications(
          newReminder,
        );
      } else {
        reminderId = widget.reminder!.id!;
        await DatabaseHelper.instance.updateBillReminder(
          reminderId,
          reminder.toMap(),
        );
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
