import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../db/model/budget.dart';
import '../db/model/category.dart';
import '../utility/amount_input.dart';
import '../utility/constant.dart';
import '../utility/appbar.dart';
import '../utility/bottombar.dart';
import '../utility/snack.dart';
import 'category_helper.dart';

class BudgetScreen extends StatefulWidget {
  static const String id = "/budget";
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Map<String, dynamic>> budgets = [];
  Map<String, double?> totalExpense = {};
  List<Map<int, double?>> expenses = [];
  @override
  void initState() {
    super.initState();
    loadBudgets();
    loadExpenses();
  }

  void loadBudgets() async {
    // Load budgets from the database
    budgets = await DatabaseHelper.instance.budgetDao.getAllBudgetsOfTheMonth(DateTime.now().year, DateTime.now().month);

    // Calculate the monthly budget total
    double total = 0;
    for (var budget in budgets) {
      total += budget['amount'] as double;
    }
    budgets.add({'total': total});

    setState(() {});
  }

  void loadExpenses() async {
    final usage = await DatabaseHelper.instance.transactionsDao.getUsage();
    totalExpense = {
      'totalExpense': (usage['totalExpense'] as num?)?.toDouble() ?? 0.0,
    };

    // Directly use the DAO result: List<Map<int, double?>>
    expenses =
        await DatabaseHelper.instance.transactionsDao.getCategoryExpense();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: 'Budget', isBackButton: false),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Monthly card takes its natural height
            MonthlyBudgetSection(
              budget:
                  budgets.where((b) => b.containsKey('total')).isNotEmpty
                      ? budgets.firstWhere(
                            (b) => b.containsKey('total'),
                          )['total']
                          as double
                      : 0.0,
              totalExpense: totalExpense['totalExpense'] ?? 0.0,
            ),
            khBox, khBox,
            // Category list takes the remaining height
            Expanded(
              child: CategoryBudgetSection(
                expenses: expenses,
                budgets: budgets,
                onReload: () {
                  loadBudgets();
                  loadExpenses();
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomBar(currentIndex: 2),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddBudgetDialog(onSave: loadBudgets),
          );
        },
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhite,
        shape: const CircleBorder(),
        child: const Icon(FontAwesomeIcons.plus, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class AddBudgetDialog extends StatefulWidget {
  final VoidCallback onSave;
  const AddBudgetDialog({super.key, required this.onSave});

  @override
  State<AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<AddBudgetDialog> {
  List<CategoryModel> categoriesData = [];
  CategoryModel? selectedCategory;
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  void loadCategories() async {
    categoriesData =
        await DatabaseHelper.instance.categoryDao.getExpenseCategories();
    if (categoriesData.isNotEmpty) {
      selectedCategory = categoriesData[0];
    }
    setState(() {});
  }

  double _extractAmount() => extractAmountFromText(_textEditingController.text);

  void validateAmt(String value) {
    formatIndianCurrencyInput(_textEditingController, value);
  }

    void add() async {
    try {
      final now = DateTime.now();
      await DatabaseHelper.instance.budgetDao.insertBudget(
        BudgetModel(
          categoryId: selectedCategory!.id,
          year: now.year,
          month: now.month,
          amount: _extractAmount(),
        ),
      );
      showSnack("Budget added sucessfully!", context);
      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      showSnack("Unable to add budget!", context, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      shadowColor: Theme.of(context).cardTheme.shadowColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CategoryModel>(
                initialValue: selectedCategory,
                items:
                    categoriesData
                        .map(
                          (element) => DropdownMenuItem<CategoryModel>(
                            value: element,
                            child: Text(element.name),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),

              khBox,

              TextField(
                controller: _textEditingController,
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
                onChanged: (value) => validateAmt(value),
              ),

              khBox,

              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: add,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 1,
                  ),
                  child: Text(
                    'Add Budget',
                    style: textTheme.bodyLarge?.copyWith(color: kWhite),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MonthlyBudgetSection extends StatelessWidget {
  final double budget;
  final double totalExpense;
  const MonthlyBudgetSection({
    super.key,
    required this.budget,
    required this.totalExpense,
  });
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        boxShadow:[
                BoxShadow(
                  color: Theme.of(context).cardTheme.shadowColor!,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [kPrimaryColor, kSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Monthly Budget",
                style: textTheme.bodyLarge?.copyWith(
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('MMMM').format(DateTime.now()),
                style: textTheme.bodyLarge?.copyWith(color: kWhite),
              ),
            ],
          ),
          khBox,
          Text(
            "₹${totalExpense.toStringAsFixed(2)}",
            style: textTheme.displayLarge?.copyWith(
              fontSize: 50.0,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: kBlack.withAlpha(77),
                  offset: const Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
              color: totalExpense > budget ? kRed : kWhite,
            ),
          ),
          Text(
            "of ₹${budget.toStringAsFixed(2)} spent",
            style: textTheme.bodyLarge?.copyWith(color: kWhite),
          ),
          khBox,
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(50.0)),
            child: LinearProgressIndicator(
              value: 0.5, 
              valueColor: const AlwaysStoppedAnimation<Color>(kWhite),
              backgroundColor: kWhite.withAlpha(77),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}
