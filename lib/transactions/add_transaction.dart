import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../bank/bank.dart';
import '../db/database_helper.dart';
import '../db/model/bank.dart';
import '../utility/appbar.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

class AddTransaction extends StatefulWidget {
  const AddTransaction({super.key});

  static const String id = "/transaction/add";

  @override
  State<AddTransaction> createState() => _AddTransactionState();
}

class _AddTransactionState extends State<AddTransaction> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  double _amount = 0.0;
  final List<String> _types = const ['Expense', 'Income', 'Lend', 'Borrow'];
  int _typeIndex = 0;

  late String _selectedCategory = categoryIcons.keys.first;
  DateTime _selectedDate = DateTime.now();

  List<Bank> _banks = [];
  int? _selectedBankId;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  //date picker for the transaction date
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.month - 1),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) return;

    final initialTime = TimeOfDay.fromDateTime(_selectedDate);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    final time = pickedTime ?? initialTime;
    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        time.hour,
        time.minute,
      );
    });
  }

  //load banks data from the db and also default selected bank
  Future<void> _loadBanks() async {
    try {
      final data = await DatabaseHelper.instance.bankDao.getBanks();
      if (!mounted) return;
      setState(() {
        _banks = data;
        // Prefer default bank, else first else creeate a non null dummy bank to avoid app crash due to null id
        final def = _banks.firstWhere(
          (b) => (b.isDefault ?? false),
          orElse:
              () =>
                  _banks.isNotEmpty
                      ? _banks.first
                      : Bank(id: null, name: '', balance: 0),
        );
        _selectedBankId = def.id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _banks = [];
        _selectedBankId = null;
      });
    }
  }

  // Helper to extract numeric value from formatted controller text
  double _extractAmount() {
    final raw = _amountController.text.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(raw) ?? 0;
  }

  //save data to the db of the transaction
  //if no bank is created prompt to create bank first
  //else save transaction and update bank balance
  Future<void> _save() async {
    final textTheme = Theme.of(context).textTheme;
    List<Bank> banks;
    // Basic client-side validation
    _amount = _extractAmount();
    if (_amount <= 0.0) {
      showSnack('Enter a valid amount', context, error: true);
      return;
    }

    try {
      banks = await DatabaseHelper.instance.bankDao.getBanks();
      if (banks.isEmpty) {
        if (!mounted) return;
        addBankDialog(
          context,
          title: 'No banks found',
          message: 'Please add a bank account before adding transactions.',
          textTheme: textTheme,
        );
        return;
      }

      //bank's balance after transaction
      double balance =
          banks.firstWhere((b) => b.id == _selectedBankId!).balance!;
      switch (_types[_typeIndex].toLowerCase()) {
        case 'income':
          balance += _amount; // add funds
          break;
        case 'expense':
          balance -= _amount; // subtract funds
          break;
        case 'borrow':
          balance += _amount; // add funds
          break;
        case 'lend':
          balance -= _amount; // subtract funds
          break;
        default:
          balance = balance;
      }
      
      final data = <String, dynamic>{
        'bank_id': _selectedBankId,
        'amount': _amount,
        'balance': balance,
        'type': _types[_typeIndex].toLowerCase(),
        'date': _selectedDate.toIso8601String(),
        'category': (_types[_typeIndex].toLowerCase() != 'expense')
        ? _types[_typeIndex]
        : _selectedCategory,
        'notes': _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim(),
      };
      //add transaction to the db
      await DatabaseHelper.instance.transactionsDao.insertTransaction(data);

      if (!mounted) return;
      showSnack('Transaction added', context);
      Navigator.pop(context);
    } catch (e) {
      showSnack('Failed to add transaction', context, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: Appbar(title: 'Add Transaction', isBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Amount',
                style: textTheme.titleSmall?.copyWith(color: kGrey),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    textAlign: TextAlign.center,
                    style: textTheme.displayLarge,
                    cursorColor: kSecondaryColor,
                    decoration: const InputDecoration(
                      hintText: '₹ 0.00',
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      // sanitize & format
                      validateAmt(value);
                      // store numeric amount
                      _amount = _extractAmount();
                    },
                  ),
                ),
              ],
            ),
            khBox,

            // Segmented type selector
            Center(
              child: Container(
                child: ToggleButtons(
                  isSelected: List.generate(
                    _types.length,
                    (i) => i == _typeIndex,
                  ),
                  onPressed: (i) => setState(() => _typeIndex = i),
                  borderRadius: BorderRadius.circular(16),
                  fillColor: kPrimaryColor,
                  selectedBorderColor: kPrimaryColor,
                  constraints: const BoxConstraints(
                    minHeight: 36,
                    minWidth: 90,
                  ),
                  children:
                      _types
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Text(t, style: textTheme.bodyLarge),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
            khBox,

            // Category selector card
            if(_typeIndex==0)
            _TileCard(
              icon: categoryIcons[_selectedCategory] ?? FontAwesomeIcons.shapes,
              title: 'Category',
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  items:
                      categoryIcons.keys
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCategory = v);
                  },
                ),
              ),
            ),
            khBox,

            //Bank selections card
            _TileCard(
              icon: FontAwesomeIcons.bank,
              title: 'Bank',
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedBankId,
                  hint: const Text('Select'),
                  items:
                      _banks.map((b) {
                        final name = b.name ?? 'Unnamed';
                        final display =
                            name.length > 10
                                ? '${name.substring(0, 10)}...'
                                : name;
                        return DropdownMenuItem<int>(
                          value: b.id,
                          child: Text(display, style: textTheme.bodyLarge),
                        );
                      }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedBankId = v);
                  },
                ),
              ),
            ),
            khBox,

            // Date selector card
            _TileCard(
              icon: FontAwesomeIcons.calendar,
              title: 'Date & Time',
              trailing: InkWell(
                onTap: () async {
                  _pickDate();
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat(
                          'dd/MM/yyyy • hh:mm:ss a',
                        ).format(_selectedDate),
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
            khBox,

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              cursorColor: kSecondaryColor,
              decoration: kBaseInputDecoration.copyWith(labelText: 'Notes...'),
            ),

            khBox, khBox,

            // CTA
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
                child: Text(
                  'Add Transaction',
                  style: textTheme.bodyLarge?.copyWith(color: kWhite),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  //valiadate the transaction amount input field and format it in indian currency format
  void validateAmt(String value) {
    // Remove everything except digits and dot
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty) {
      setState(() {
        _amountController.value = const TextEditingValue(text: '');
      });
      return;
    }

    // Allow only one dot and max 2 decimals
    final dotIndex = cleaned.indexOf('.');
    String finalText;
    if (dotIndex == -1) {
      finalText = cleaned;
    } else {
      final before = cleaned.substring(0, dotIndex);
      final afterRaw = cleaned.substring(dotIndex + 1).replaceAll('.', '');
      final after = afterRaw.length > 2 ? afterRaw.substring(0, 2) : afterRaw;
      // Preserve trailing dot if user just typed it
      finalText = afterRaw.isEmpty ? '$before.' : '$before.$after';
    }

    // Format integer part with Indian grouping, keep user-entered decimals
    final parts = finalText.split('.');
    final intPart = parts[0].isEmpty ? '0' : parts[0];
    final formattedInt = NumberFormat.decimalPattern(
      'en_IN',
    ).format(int.tryParse(intPart) ?? 0);

    String formatted = formattedInt;
    if (finalText.contains('.')) {
      // Handle trailing dot and decimals
      if (finalText.endsWith('.')) {
        formatted = '$formattedInt.';
      } else {
        formatted = '$formattedInt.${parts[1]}';
      }
    }

    final display = '₹ $formatted';

    if (display != _amountController.text) {
      setState(() {
        _amountController.value = TextEditingValue(
          text: display,
          selection: TextSelection.collapsed(offset: display.length),
        );
      });
    }
  }

  //if bank not found show this dialog to add bank first
  void addBankDialog(
    BuildContext context, {
    required String title,
    required String message,
    required TextTheme textTheme,
  }) async {
    return await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('No Banks Found', style: textTheme.bodyLarge),
            content: Text(
              'Add a bank before adding transactions.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: textTheme.bodyMedium),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, BankScreen.id);
                },

                child: Text(
                  'Add Bank',
                  style: textTheme.bodyMedium?.copyWith(color: kPrimaryColor),
                ),
              ),
            ],
          ),
    );
  }
}

//tile card widget for various selections
class _TileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _TileCard({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: kGrey.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: kGrey.withAlpha(25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kSecondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kSecondaryColor),
          ),
          kwBox,
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          trailing,
        ],
      ),
    );
  }
}
