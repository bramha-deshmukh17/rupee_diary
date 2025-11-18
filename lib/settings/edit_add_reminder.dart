import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';
import '../services/reminder_notification.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      _amountController.text = widget.reminder!.amount.toString();
      _notesController.text = widget.reminder!.notes ?? '';
      _selectedDate = widget.reminder!.dueDate;
      _selectedCategory = widget.reminder!.category.toString();
      _isRecurring = widget.reminder!.isRecurring.toString() == 'true';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelColor =
        Theme.of(context).brightness == Brightness.dark ? kWhite : kBlack;

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
                  decoration: kBaseInputDecoration.copyWith(
                    labelText: 'Bill Title*',
                    labelStyle: TextStyle(color: labelColor),
                  ),
                  cursorColor: kSecondaryColor,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                khBox,
                TextFormField(
                  controller: _amountController,
                  decoration: kBaseInputDecoration.copyWith(
                    labelText: 'Amount*',
                    labelStyle: TextStyle(color: labelColor),
                    prefixText: '₹',
                  ),
                  cursorColor: kSecondaryColor,
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
                khBox,
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: kBaseInputDecoration.copyWith(
                    labelText: 'Category',
                    prefixIcon: Icon(categoryIcons[_selectedCategory]),
                  ),
                  items:
                      categories.map((category) {
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
                    final now = DateTime.now();
                    final minDate =
                        _selectedDate.isBefore(now) ? _selectedDate : now;

                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(
                        minDate.year,
                        minDate.month,
                        minDate.day,
                      ),
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
                  checkColor: kSecondaryColor,
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
                  decoration: kBaseInputDecoration.copyWith(
                    labelText: 'Notes (Optional)',
                    labelStyle: TextStyle(color: labelColor),
                    ),
                
                  cursorColor: kSecondaryColor,
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
    if (!_formKey.currentState!.validate()) return;

    try {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
     
      final reminder = BillReminderModel(
        id: widget.reminder?.id,
        title: _titleController.text.trim(),
        amount: amount,
        dueDate: _selectedDate,
        category: _selectedCategory,
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
        isRecurring: _isRecurring,
        isPaid: widget.reminder?.isPaid ?? false,
      );

      int reminderId;

      if (widget.reminder == null) {
        // Insert
        try {
          reminderId = await DatabaseHelper.instance.billReminderDao
              .insertBillReminder(reminder.toMap());
        } catch (e) {
          if (!mounted) return;
          showSnack('Failed to save reminder', context, error: true);
          return;
        }

        // Schedule (non-fatal)
        final newReminder = reminder.copyWith(id: reminderId);
        try {
          await ReminderNotificationService.scheduleReminderNotifications(
            newReminder,
          );
        } catch (e) {
          if (mounted) {
            showSnack(
              'Saved, but failed to schedule notifications',
              context,
              error: true,
            );
          }
        }

        if (mounted) showSnack('Reminder added', context);
      } else {
        // Update
        reminderId = widget.reminder!.id!;
        try {
          await DatabaseHelper.instance.billReminderDao.updateBillReminder(
            reminderId,
            reminder.toMap(),
          );
        } catch (e) {
          if (!mounted) return;
          showSnack('Failed to update reminder', context, error: true);
          return;
        }

        // Reschedule (best-effort)
        try {
          await ReminderNotificationService.cancelReminderNotifications(
            reminderId,
          );
        } catch (_) {}
        final updatedReminder = reminder.copyWith(id: reminderId);
        try {
          await ReminderNotificationService.scheduleReminderNotifications(
            updatedReminder,
          );
        } catch (e) {
          if (mounted) {
            showSnack(
              'Updated, but failed to reschedule notifications',
              context,
              error: true,
            );
          }
        }

        if (mounted) showSnack('Reminder updated', context);
      }

      widget.onSave();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showSnack('Something went wrong while saving', context, error: true);
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
