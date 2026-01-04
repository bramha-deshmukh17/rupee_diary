import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../bank/bank.dart';
import '../db/database_helper.dart';
import '../db/model/bank.dart';
import '../db/model/category.dart';
import '../utility/amount_input.dart';
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

  //list of all categories loaded from db
  List<CategoryModel> _categories = [];

  //list of only expense categories for dropdown
  List<CategoryModel> _expenseCategories = [];

  //currently selected expense category
  CategoryModel? _selectedCategory;

  DateTime _selectedDate = DateTime.now();

  List<BankModel> _banks = [];
  int? _selectedBankId;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _loadCategories(); //load categories and icons from db on screen init
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  //load category names and icons from db
  Future<void> _loadCategories() async {
    try {
      final categories =
          await DatabaseHelper.instance.categoryDao.getAllCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;

        //filter only expense categories (exclude special types)
        _expenseCategories =
            categories.where((c) {
              final n = c.name.toLowerCase();
              return n != 'income' &&
                  n != 'lend' &&
                  n != 'borrow' &&
                  n != 'settlement';
            }).toList();

        //set default selected category for expense
        if (_selectedCategory == null && _expenseCategories.isNotEmpty) {
          _selectedCategory = _expenseCategories.first;
        }
      });
    } catch (_) {
      showSnack("Failed to load categories. Try again later...!", context, error: true);
    }
  }

  //load banks data from the db and also default selected bank
  Future<void> _loadBanks() async {
    try {
      final data = await DatabaseHelper.instance.bankDao.getBanks();
      if (!mounted) return;
      setState(() {
        _banks = data;
        //prefer default bank, else first, else create a dummy bank to avoid null id crash
        final def = _banks.firstWhere(
          (b) => (b.isDefault ?? false),
          orElse:
              () =>
                  _banks.isNotEmpty
                      ? _banks.first
                      : BankModel(id: null, name: '', balance: 0),
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

  // Helper to extract numeric value from formatted controller text
  double _extractAmount() => extractAmountFromText(_amountController.text);

  void validateAmt(String value) {
    formatIndianCurrencyInput(_amountController, value);
  }

  //resolve category id for non-expense types from db (Income/Lend/Borrow/Settlement)
  int? _categoryIdByTypeName(String typeName) {
    final lower = typeName.toLowerCase();
    try {
      final c = _categories.firstWhere(
        (cat) => cat.name.toLowerCase() == lower,
      );
      return c.id;
    } catch (_) {
      return null;
    }
  }

  //save data to the db of the transaction
  //if no bank is created prompt to create bank first
  //else save transaction and update bank balance
  Future<void> _save() async {
    final textTheme = Theme.of(context).textTheme;
    List<BankModel> banks;

    //basic client-side validation
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
      final typeLower = _types[_typeIndex].toLowerCase();

      switch (typeLower) {
        case 'income':
        case 'borrow':
          balance += _amount; //add funds
          break;
        case 'expense':
        case 'lend':
          balance -= _amount; //subtract funds
          break;
      }

      int? categoryId;

      if (typeLower == 'expense') {
        //for expense use selected category from db
        categoryId = _selectedCategory?.id;
      } else {
        //for income/lend/borrow use special category rows in db
        categoryId = _categoryIdByTypeName(_types[_typeIndex]);
      }

      if (categoryId == null) {
        showSnack(
          'Category not found in database. Please check categories setup.',
          context,
          error: true,
        );
        return;
      }

      final data = <String, dynamic>{
        'bankId': _selectedBankId,
        'amount': _amount,
        'balance': balance,
        'type': typeLower,
        'date': _selectedDate.toIso8601String(),
        'categoryId': categoryId,
        'notes':
            _notesController.text.trim().isEmpty
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

    //pick icon for currently selected category from db, fallback to generic icon
    final IconData categoryIcon =
        _selectedCategory?.icon ?? FontAwesomeIcons.shapes;

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
                      //sanitize & format
                      validateAmt(value);
                      //store numeric amount
                      _amount = _extractAmount();
                    },
                  ),
                ),
              ],
            ),
            khBox,

            // Segmented type selector
            Center(
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
            khBox,

            // Category selector (Expense only)
            if (_typeIndex == 0)
              _TileCard(
                icon: categoryIcon,
                title: 'Category',
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<CategoryModel>(
                    value: _selectedCategory,
                    items:
                        _expenseCategories
                            .map(
                              (cat) => DropdownMenuItem<CategoryModel>(
                                value: cat,
                                child: Text(cat.name),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      setState(() => _selectedCategory = v);
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

            khBox,
            khBox,

            // Add button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: kWhite,
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
            khBox,
          ],
        ),
      ),
    );
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
            backgroundColor: Theme.of(context).cardTheme.color,
            shadowColor: Theme.of(context).cardTheme.shadowColor,
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
        color: Theme.of(context).cardTheme.color,
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
              color: kSecondaryColor.withAlpha(25),
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
