import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../db/database_helper.dart';
import '../db/model/bank.dart';
import '../utility/appbar.dart';
import '../utility/bottombar.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

class BankScreen extends StatefulWidget {
  const BankScreen({super.key});
  static const String id = '/bank';

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  List<BankModel> _banks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  //loading bank data from db
  Future<void> _loadBanks() async {
    setState(() => _loading = true);
    try {
      final data = await DatabaseHelper.instance.bankDao.getBanks();
      if (!mounted) return;
      setState(() {
        _banks = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  //deleting bank
  void deleteBank(BuildContext context, BankModel b) async {
    try {
      await DatabaseHelper.instance.bankDao.deleteBank(b);
      showSnack('Bank deleted successfully', context);
      await _loadBanks();
    } catch (e) {
      showSnack('Error deleting bank', context, error: true);
    } finally {
      Navigator.pop(context); // Close the dialog
    }
  }

  //bank page to show list of banks
  //long press to delete a bank

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: Appbar(title: 'Banks'),
      body: Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 1),
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: kPrimaryColor),
                )
                : _banks.isEmpty
                ? Center(
                  child: Text('No banks added', style: textTheme.bodyLarge),
                )
                : Column(
                  children: [
                    Text(
                      "Long press to delete bank",
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.start,
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _banks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final b = _banks[i];
                          final isDefault = b.isDefault ?? false;
                          return GestureDetector(
                            onLongPress: deleteBankDialog(
                              context,
                              b,
                              _loadBanks,
                            ),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: kPrimaryColor,
                                  child: Text(
                                    b.name!.isNotEmpty
                                        ? b.name![0].toUpperCase()
                                        : '?',
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: kWhite,
                                    ),
                                  ),
                                ),
                                title: Text(b.name!),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isDefault)
                                      Text(
                                        'Default',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: kGreen,
                                        ),
                                      ),
                                    Text(
                                      '₹${b.balance!.toStringAsFixed(2)}',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: b.balance! >= 0 ? kGreen : kRed,
                                      ),
                                    ),
                                  ],
                                ),
                                //icon button to make a bank default while adding a transaction
                                trailing: IconButton(
                                  tooltip:
                                      isDefault
                                          ? 'Default bank'
                                          : 'Set as default',
                                  icon: Icon(
                                    isDefault
                                        ? FontAwesomeIcons.solidStar
                                        : FontAwesomeIcons.star,
                                    color: isDefault ? kPrimaryColor : kGrey,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    changeDefaultBank(b, isDefault, context);
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      ),

      //bottom app bar
      bottomNavigationBar: BottomBar(currentIndex: 3),

      //floating action button to add bank
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhite,
        shape: const CircleBorder(),
        onPressed: () {
          // Navigate to add bank dialog
          showDialog(
            context: context,
            builder: (context) => AddBank(onSave: _loadBanks),
          );
        },
        child: const Icon(FontAwesomeIcons.plus),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  //delete bank dialog with conditions
  //taking context and bank data and loadBanks function as parameters
  GestureLongPressCallback deleteBankDialog(
    BuildContext context,
    BankModel b,
    Future<void> Function() loadBanks,
  ) {
    return () async {
      final textTheme = Theme.of(context).textTheme;
      bool result = await DatabaseHelper.instance.transactionsDao
          .getTransactionByBankId(b);

      final hasTx = result; // true if transactions exist
      String message;
      bool canDelete;

      //message in dialog according to certain scenarios
      if (b.isDefault == true && hasTx) {
        // Scenario 1: default + transactions
        message =
            "This is the default bank and has transactions. Change the default first, then delete.";
        canDelete = false;
      } else if (b.isDefault == true && !hasTx) {
        // Scenario 2: default + no transactions
        message =
            "This is the default bank. Change the default to another bank before deleting.";
        canDelete = false;
      } else if (b.isDefault != true && hasTx) {
        // Scenario 3: not default + transactions
        message =
            "'${b.name}' bank has transactions. Deleting it will also delete all its transactions. Continue?";
        canDelete = true;
      } else {
        // Scenario 4: not default + no transactions
        message = "Are you sure you want to delete the bank '${b.name}'?";
        canDelete = true;
      }

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              shadowColor: Theme.of(context).cardTheme.shadowColor,
              title: Text(
                "Delete Bank",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              content: Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: canDelete ? null : kRed,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: textTheme.bodyMedium),
                ),
                canDelete
                    ? TextButton(
                      onPressed: () {
                        deleteBank(context, b);
                      },
                      child: Text(
                        "Delete",
                        style: textTheme.bodyLarge?.copyWith(color: kRed),
                      ),
                    )
                    : const SizedBox(),
              ],
            ),
      );
    };
  }

  //method to make a bank account default
  void changeDefaultBank(
    BankModel b,
    bool isDefault,
    BuildContext context,
  ) async {
    if (isDefault) return;
    try {
      await DatabaseHelper.instance.bankDao.setDefault(b.id!);
      await _loadBanks();
      showSnack('Default bank set', context);
    } catch (e) {
      showSnack('Failed to set default', context, error: true);
    }
  }
}

//add bank dialog appearing after clicking floating action button
class AddBank extends StatefulWidget {
  final VoidCallback onSave;

  const AddBank({super.key, required this.onSave});

  @override
  State<AddBank> createState() => _AddBankState();
}

class _AddBankState extends State<AddBank> {
  //controllers and focus nodes
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _initialBalanceController =
      TextEditingController();
  final FocusNode _balanceFocusNode = FocusNode();
  String? _errorBalance, _errorName;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _initialBalanceController.dispose();
    _balanceFocusNode.dispose();
    super.dispose();
  }

  //validate the balace input to allow only numbers and decimal point
  void balanceValidate(String value) {
    String cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');

    if (cleaned.isEmpty) {
      _initialBalanceController.value = const TextEditingValue(text: '');
      return;
    }
    if (cleaned == '.') cleaned = '0.';

    final firstDot = cleaned.indexOf('.');
    if (firstDot != -1) {
      // Keep only first dot strip others
      final before = cleaned.substring(0, firstDot);
      String afterRaw = cleaned.substring(firstDot + 1).replaceAll('.', '');
      // Limit to 2 decimal digits
      String after = afterRaw.length > 2 ? afterRaw.substring(0, 2) : afterRaw;
      cleaned = after.isEmpty ? '$before.' : '$before.$after';
    }

    if (cleaned != _initialBalanceController.text) {
      _initialBalanceController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
  }

  //function to add bank to db using alert box
  void addBank(BuildContext context) async {
    String name = _bankNameController.text.trim();
    String balanceText = _initialBalanceController.text.trim();
    double balance = double.tryParse(balanceText) ?? 0.0;

    if (name.isEmpty) {
      setState(() {
        _errorName = 'Please enter a bank name';
      });
      return;
    }

    if (balanceText.isEmpty) {
      setState(() {
        _errorBalance = 'Please enter an initial balance';
      });
      return;
    }

    try {
      final newBank = BankModel(name: name, balance: balance);
      await DatabaseHelper.instance.bankDao.insertBank(newBank);
      widget.onSave();
      showSnack("Bank '$name' added", context);
    } catch (e) {
      showSnack('Error adding bank "$name"', context, error: true);
    } finally {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text("Enter Bank Details"),
      backgroundColor: Theme.of(context).cardTheme.color,
      shadowColor: Theme.of(context).cardTheme.shadowColor,
      content: SizedBox(
        height: 150.0,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Bank Name',
                errorText: _errorName,
              ),
              controller: _bankNameController,
              style: TextStyle(),
              onSubmitted:
                  (_) => FocusScope.of(context).requestFocus(_balanceFocusNode),
            ),
            khBox,
            TextField(
              decoration: InputDecoration(
                labelText: 'Initial Balance',
                errorText: _errorBalance,
              ),
              style: textTheme.bodyMedium,
              focusNode: _balanceFocusNode,
              controller: _initialBalanceController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                balanceValidate(value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
          },
          child: Text("cancel", style: textTheme.bodyMedium),
        ),
        TextButton(
          onPressed: () {
            addBank(context);
          },
          child: Text(
            "Save",
            style: textTheme.bodyLarge?.copyWith(color: kPrimaryColor),
          ),
        ),
      ],
    );
  }
}
