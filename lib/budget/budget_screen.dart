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
    budgets = await DatabaseHelper.instance.budgetDao.getAllBudgets();

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
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
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
      await DatabaseHelper.instance.budgetDao.insertBudget(
        BudgetModel(categoryId: selectedCategory!.id, amount: _extractAmount()),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CategoryModel>(
                value: selectedCategory,
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
                    foregroundColor: Colors.white,
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
                  color: kBlack.withOpacity(0.3),
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
              backgroundColor: kWhite.withOpacity(0.3),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryBudgetSection extends StatelessWidget {
  final List<Map<int, double?>> expenses;
  final List<Map<String, dynamic>> budgets;
  final VoidCallback onReload;

  const CategoryBudgetSection({
    super.key,
    required this.expenses,
    required this.budgets,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Category Budgets", style: textTheme.headlineMedium),
        khBox,
        if (budgets.isEmpty || budgets.length == 1)
          Text(
            "No budgets set. Tap + to add a budget.",
            style: textTheme.bodyMedium,
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: budgets.length - 1,
              itemBuilder: (context, index) {
                final budget = budgets[index];
                final categoryId = budget['categoryId'] as int;
                final spent =
                    expenses.firstWhere(
                      (e) => e.containsKey(categoryId),
                      orElse: () => {categoryId: 0.0},
                    )[categoryId] ??
                    0.0;

                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (ctx) => EditBudget(
                            budgetId: budget['id'] as int,
                            categoryName: budget['category'] as String,
                            onSave:
                                onReload, // will call loadBudgets + loadExpenses
                          ),
                    );
                  },
                  child: CategoryBudgetCard(
                    id: budget['id'] as int,
                    icon: IconData(
                      budget['icon_code_point'] as int,
                      fontFamily: budget['icon_font_family'] as String,
                      fontPackage: budget['icon_font_package'] as String?,
                    ),
                    title: budget['category'] as String,
                    spent: spent,
                    total: budget['amount'] as double,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class CategoryBudgetCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double spent;
  final double total;
  final int id;

  const CategoryBudgetCard({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.spent,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOver = spent > total;
    final progress = (spent / total).clamp(0.0, 1.0);
    final remaining = (total - spent).abs();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kPrimaryColor, size: 20),
              ),
              kwBox,

              // Title
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹${spent.toInt()} / ₹${total.toInt()}",
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOver
                        ? "₹${remaining.toInt()} over"
                        : "₹${remaining.toInt()} left",
                    style: textTheme.bodySmall?.copyWith(
                      color: isOver ? kRed : kGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          khBox,

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? kRed : kSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditBudget extends StatelessWidget {
  final int budgetId;
  final String categoryName;
  final VoidCallback onSave;
  final TextEditingController amountController = TextEditingController();

  EditBudget({
    super.key,
    required this.budgetId,
    required this.categoryName,
    required this.onSave,
  });

  double _extractAmount() => extractAmountFromText(amountController.text);

  void validateAmt(String value) {
    formatIndianCurrencyInput(amountController, value);
  }

  Future<bool> update() async {
    final amount = _extractAmount();
    try {
      await DatabaseHelper.instance.budgetDao.updateBudget(budgetId, amount);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(categoryName, style: textTheme.bodyLarge),
          khBox,
          TextField(
            controller: amountController,
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
              onPressed: () async {
                final ok = await update();
                showSnack(
                  ok ? "Updated sucessfully" : "Failed to update",
                  context,
                );
                if (ok) {
                  onSave(); // reload budgets in parent
                  Navigator.of(context).pop(); // close dialog
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1,
              ),
              child: Text(
                'Update Budget',
                style: textTheme.bodyLarge?.copyWith(color: kWhite),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
