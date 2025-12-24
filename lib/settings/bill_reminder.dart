import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../db/model/bill_reminder.dart';
import '../utility/appbar.dart';
import '../utility/constant.dart';
import '../services/reminder_notification.dart';
import '../utility/snack.dart';

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

  //load all the available bill reminders from the database
  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = await DatabaseHelper.instance.billReminderDao.getAll();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack('Failed to load reminders', context, error: true);
    }
  }

  //delete a bill reminder
  Future<void> _deleteReminder(BillReminderModel reminder) async {
    try {
      if (reminder.id == null) {
        showSnack('Invalid reminder (missing id)', context, error: true);
        return;
      }

      // Best-effort cancel notifications (non-fatal if it fails)
      try {
        await ReminderNotificationService.cancelReminderNotifications(
          reminder.id!,
        );
      } catch (e) {
        // Keep going; still delete from DB
      }

      await DatabaseHelper.instance.billReminderDao.deleteBillReminder(
        reminder.id!,
      );
      //reload the reminders data after deletion
      await _loadReminders();
      if (!mounted) return;
      showSnack('Reminder deleted', context);
    } catch (e) {
      if (!mounted) return;
      showSnack('Failed to delete reminder', context, error: true);
    }
  }

  //show add edit dialog has onSave attribut when called implicitely call the function which is passed as parameter
  //here that function is loadreminder
  void _showAddEditDialog([BillReminderModel? reminder]) {
    showDialog(
      context: context,
      builder:
          (context) => AddEditReminderDialog(
            reminder: reminder,
            //wheneever onSave() is called by AddEditReminderDialog it will call _loadReminders function to reload the data from db
            onSave: () {
              _loadReminders();
            },
          ),
    );
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
      appBar: const Appbar(title: "Bill Reminders", isBackButton: true),
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
        child: const Icon(FontAwesomeIcons.plus, color: kWhite),
      ),
    );
  }

  //if no reminders added then show this widget
  Widget _buildEmptyState() {
    final textTheme = TextTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.fileInvoice, size: 64, color: kGrey),
          khBox,
          Text(
            'No Bill Reminders',
            textAlign: TextAlign.center,
            style: textTheme.displayLarge?.copyWith(color: kGrey),
          ),
          Text(
            'Add your first bill reminder to get started',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(color: kGrey),
          ),
        ],
      ),
    );
  }

  //show all the list of reminders in a card format
  Widget _buildReminderCard(BillReminderModel reminder) {
    final iconData = kCategoryIcons[reminder.category] ?? Icons.category;
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
              '₹ ${reminder.amount.toStringAsFixed(2)}',
              style: textTheme.bodyMedium?.copyWith(color: kRed),
            ),
            Text(
              'Due: ${DateFormat('dd/MM/yyyy').format(reminder.dueDate)}',
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
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(FontAwesomeIcons.pencil, size: 18),
                      kwBox,
                      Text('Edit', style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(FontAwesomeIcons.trash, size: 18, color: kRed),
                      kwBox,
                      Text(
                        'Delete',
                        style: textTheme.bodyMedium?.copyWith(color: kRed),
                      ),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }
}

//reminder add edit dialog
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

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _categoryNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

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
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _amountFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
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
                  style: textTheme.headlineMedium,
                ),
                khBox,
                TextFormField(
                  controller: _titleController,
                  onFieldSubmitted: (val) {
                    FocusScope.of(context).requestFocus(_amountFocusNode);
                  },
                  decoration: kBaseOutlineDecoration.copyWith(
                    labelText: 'Bill Title*',
                  ),
                  style: textTheme.bodyLarge,
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
                  focusNode: _amountFocusNode,
                  style: textTheme.bodyLarge,
                  onFieldSubmitted: (val) {
                    FocusScope.of(context).requestFocus(_categoryNode);
                  },
                  decoration: kBaseOutlineDecoration.copyWith(
                    labelText: 'Amount*',
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
                  style: textTheme.bodyLarge,
                  initialValue: _selectedCategory,
                  focusNode: _categoryNode,
                  decoration: kBaseOutlineDecoration.copyWith(
                    labelText: 'Category',
                    prefixIcon: Icon(kCategoryIcons[_selectedCategory]),
                  ),
                  items:
                      kCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category, style: textTheme.bodyLarge),
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
                      border: Border.all(color: kGrey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Due Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                          style: textTheme.bodyLarge,
                        ),
                        const Icon(FontAwesomeIcons.calendar),
                      ],
                    ),
                  ),
                ),
                khBox,
                CheckboxListTile(
                  title: Text(
                    'Monthly Recurring Bill',
                    style: textTheme.bodyLarge,
                  ),
                  value: _isRecurring,
                  checkColor: kSecondaryColor,
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value!;
                    });
                    FocusScope.of(context).requestFocus(_notesFocusNode);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                khBox,
                TextFormField(
                  controller: _notesController,
                  focusNode: _notesFocusNode,
                  decoration: kBaseOutlineDecoration.copyWith(
                    labelText: 'Notes (Optional)',
                  ),
                  style: textTheme.bodyLarge,
                  cursorColor: kSecondaryColor,
                  maxLines: 3,
                ),

                khBox,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: textTheme.bodyMedium),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveReminder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: kWhite,
                      ),
                      child: Text(
                        widget.reminder == null ? 'Add' : 'Update',
                        style: textTheme.bodyMedium?.copyWith(color: kWhite),
                      ),
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

  //function to get data and save/update in db
  //also schedule the reminder notification for the bill reminder
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

        // Reschedule
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

      //when saved/updated successfully callback will call save method from invoking class 
      //i.e. BillReminder class to reload the data from db using loadreminder function
      widget.onSave();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showSnack('Something went wrong while saving', context, error: true);
    }
  }
}
