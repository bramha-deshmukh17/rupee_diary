import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../db/database_helper.dart';
import '../utility/amount_input.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

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
        Text(
          "Long Press to delete budget",
          style: textTheme.bodySmall?.copyWith(color: kGrey),
        ),
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
                          (_) => EditBudget(
                            budgetId: budget['id'] as int,
                            categoryName: budget['category'] as String,
                            amount: budget['amount'] as double,
                            onSave:
                                onReload, // will call loadBudgets + loadExpenses
                          ),
                    );
                  },
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder:
                          (_) => DeleteBudgetDialog(
                            budgetId: budget['id'] as int,
                            categoryName: budget['category'] as String,
                            onDeleted: onReload, // reload budgets in parent
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

    return Card(
      child: Padding(
        padding: EdgeInsetsGeometry.all(10.0),
        child: Column(
          children: [
            Row(
              children: [
                // Icon box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: kPrimaryColor, size: 20),
                ),
                kwBox,

                // Title
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Amount
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.30,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(FontAwesomeIcons.pen, size: 15.0),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          "₹${spent.toInt()} / ₹${total.toInt()}",
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          isOver
                              ? "₹${remaining.toInt()} over"
                              : "₹${remaining.toInt()} left",
                          style: textTheme.bodySmall?.copyWith(
                            color: isOver ? kRed : kGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
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
      ),
    );
  }
}

class EditBudget extends StatefulWidget {
  final int budgetId;
  final String categoryName;
  final VoidCallback onSave;
  final double amount;

  const EditBudget({
    super.key,
    required this.budgetId,
    required this.categoryName,
    required this.onSave,
    required this.amount,
  });

  @override
  State<EditBudget> createState() => _EditBudgetState();
}

class _EditBudgetState extends State<EditBudget> {
  late TextEditingController amountController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(text: widget.amount.toString());
    // Request focus when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  double _extractAmount() => extractAmountFromText(amountController.text);

  void validateAmt(String value) {
    formatIndianCurrencyInput(amountController, value);
  }

  Future<bool> update() async {
    final amount = _extractAmount();
    try {
      return await DatabaseHelper.instance.budgetDao.updateBudget(
        widget.budgetId,
        amount,
      );
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      shadowColor: Theme.of(context).cardTheme.shadowColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.categoryName, style: textTheme.bodyLarge),
          khBox,
          TextField(
            controller: amountController,
            focusNode: _focusNode,
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
                  widget.onSave(); // reload budgets in parent
                  Navigator.of(context).pop(); // close dialog
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: kWhite,
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

class DeleteBudgetDialog extends StatelessWidget {
  final int budgetId;
  final String categoryName;
  final VoidCallback onDeleted;

  const DeleteBudgetDialog({
    super.key,
    required this.budgetId,
    required this.categoryName,
    required this.onDeleted,
  });

  Future<bool> _delete() async {
    try {
      return await DatabaseHelper.instance.budgetDao.deleteBudget(budgetId);
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
          khBox,
          Text(
            "Are you sure you want to delete $categoryName's budget?",
            style: textTheme.bodyMedium,
          ),
          khBox,
          SizedBox(
            height: 48,
            width: 200,
            child: ElevatedButton(
              onPressed: () async {
                final ok = await _delete();
                showSnack(
                  ok ? "Deleted sucessfully" : "Failed to delete",
                  context,
                );
                if (ok) {
                  onDeleted(); // reload budgets in parent
                  Navigator.of(context).pop(); // close dialog
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1,
              ),
              child: Text(
                'Delete Budget',
                style: textTheme.bodyLarge?.copyWith(color: kWhite),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
