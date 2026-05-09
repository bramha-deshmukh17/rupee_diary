import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../db/database_helper.dart';
import '../db/model/transactions.dart';
import '../transactions/history.dart';
import '../transactions/transaction_tile.dart';
import '../utility/constant.dart';
import '../services/route_observer.dart';
import '../transactions/add_transaction.dart';
import '../utility/appbar.dart';
import '../services/reminder_notification.dart';
import '../utility/bottombar.dart';
import '../utility/snack.dart';

class HomeScreen extends StatefulWidget {
  static const String id = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  int _badgeCount = 0;
  double? totalBalance, totalIncome, totalExpense;
  List<TransactionModel>? latestTransaction;

  @override
  void initState() {
    super.initState();
    //get todays and tomorrows notification count to show on the  bell icon
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ReminderNotificationService.getTodayTomorrowPendingCount();
      _refreshBadge();
    });
    loadData();
  }

  Future<void> loadData() async {
    try {
      //load the total exxpense, income and money left from all bank account
      final usage = await DatabaseHelper.instance.transactionsDao.getUsage();
      //get last 5 transactions
      final transactions =
          await DatabaseHelper.instance.transactionsDao.getRecentTransactions();

      if (!mounted) return;
      setState(() {
        totalBalance = usage['totalBalance'];
        totalIncome = usage['totalIncome'];
        totalExpense = usage['totalExpense'];
        latestTransaction = transactions.isNotEmpty ? transactions : null;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack('Failed to load summary data', context, error: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    //here we are using route observer to know that we have came back to the home screen
    //so that it will reload the data on the home page
    //because there might be a scenario that we have added a transaction/reminder or deleted a transaction
    //in this we need to update the data on home screen but it won't happen without any interaction
    //so using routeObserveer we need not to have a explicite interaction it will automatically update the data
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshBadge(); // refresh when notification count returning to Home
    loadData(); // refresh the data as well
  }

  //refresh the notification count on the bell icon
  Future<void> _refreshBadge() async {
    try {
      final reminderCount =
          await ReminderNotificationService.getTodayTomorrowPendingCount();
      final overBudgetCount = await _getOverBudgetCategoryCount();
      if (!mounted) return;
      setState(() => _badgeCount = reminderCount + overBudgetCount);
    } catch (e) {
      if (!mounted) return;
      showSnack('Failed to refresh reminders', context, error: true);
    }
  }

  // get number of over-budget categories for current month
  Future<int> _getOverBudgetCategoryCount() async {
    final now = DateTime.now();
    final budDao = DatabaseHelper.instance.budgetDao;
    final txDao = DatabaseHelper.instance.transactionsDao;

    // category-wise budgets for current month
    final budgetRows = await budDao.getAllBudgetsOfTheMonth(
      now.year,
      now.month,
    );
    final budgetByCat = <int, double>{};
    for (final row in budgetRows) {
      final catId = row['categoryId'] as int;
      final amount = (row['amount'] as num).toDouble();
      budgetByCat[catId] = amount;
    }

    // category-wise expenses for current month
    final expenseRows = await txDao.getCategoryExpense();
    final expenseByCat = <int, double>{};
    for (final m in expenseRows) {
      m.forEach((catId, val) {
        final v = (val as num?)?.toDouble() ?? 0.0;
        expenseByCat[catId] = (expenseByCat[catId] ?? 0.0) + v;
      });
    }

    int count = 0;
    budgetByCat.forEach((catId, budget) {
      final spent = expenseByCat[catId] ?? 0.0;
      if (budget > 0 && spent > budget) {
        count++;
      }
    });
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: "Home", appbarIcons: true, badgeCount: _badgeCount),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            khBox,
            BalanceCard(
              balance: totalBalance ?? 0.0,
              income: totalIncome ?? 0.0,
              expense: totalExpense ?? 0.0,
            ),
            khBox,
            // Pass the list of transactions to the list widget
            TransactionsList(transactions: latestTransaction),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(currentIndex: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AddTransaction.id);
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

//balance card showing the total balance left in all bank total expense and income done this month
class BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).cardTheme.shadowColor!,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        gradient: const LinearGradient(
          colors: [kPrimaryColor, kSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total Balance",
            style: textTheme.bodyLarge?.copyWith(color: kWhite),
          ),
          const SizedBox(height: 8),
          // Display dynamic Balance
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              "₹${balance.toStringAsFixed(2)}",
              style: textTheme.headlineMedium?.copyWith(color: kWhite),
            ),
          ),
          khBox,
          Text(
            "This month",
            style: textTheme.bodyLarge?.copyWith(color: kWhite),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.arrowDown,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  // Display dynamic Income
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      "Income\n₹${income.toStringAsFixed(2)}",
                      style: textTheme.bodyMedium?.copyWith(color: kWhite),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.arrowUp,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  // Display dynamic Expense
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      "Expenses\n₹${expense.toStringAsFixed(2)}",
                      style: textTheme.bodyMedium?.copyWith(color: kWhite),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//display list of recent transactions here
class TransactionsList extends StatelessWidget {
  final List<TransactionModel>? transactions;

  const TransactionsList({super.key, required this.transactions});

  // Helper to pair transfer transactions
  List<dynamic> _groupedTransactions(List<TransactionModel> txList) {
    final result = <dynamic>[];
    final processedIds = <int?>{};

    for (int i = 0; i < txList.length; i++) {
      final tx = txList[i];

      if (processedIds.contains(tx.id)) continue;

      if (tx.type.toLowerCase() == 'transfer') {
        for (int j = i + 1; j < txList.length; j++) {
          final potentialPair = txList[j];

          if (potentialPair.type.toLowerCase() == 'transfer' &&
              tx.amount == potentialPair.amount &&
              tx.date.year == potentialPair.date.year &&
              tx.date.month == potentialPair.date.month &&
              tx.date.day == potentialPair.date.day &&
              tx.categoryId == potentialPair.categoryId &&
              tx.bankName != potentialPair.bankName) {
            result.add(TransferPair(sender: tx, receiver: potentialPair));
            processedIds.add(tx.id);
            processedIds.add(potentialPair.id);
            break;
          }
        }

        if (!processedIds.contains(tx.id)) {
          result.add(tx);
          processedIds.add(tx.id);
        }
      } else {
        result.add(tx);
        processedIds.add(tx.id);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recent Transactions", style: textTheme.headlineMedium),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, HistoryScreen.id);
                },
                child: Text(
                  "See All",
                  style: textTheme.bodyMedium?.copyWith(color: kSecondaryColor),
                ),
              ),
            ],
          ),
          khBox,
          Expanded(
            child:
                (transactions == null || transactions!.isEmpty)
                    ? Center(
                      child: Text(
                        "No transactions yet",
                        style: textTheme.bodyMedium?.copyWith(color: kGrey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _groupedTransactions(transactions!).length,
                      itemBuilder: (context, index) {
                        final item = _groupedTransactions(transactions!)[index];

                        if (item is TransferPair) {
                          return TransferTile(
                            senderTransaction: item.sender,
                            receiverTransaction: item.receiver,
                          );
                        } else if (item is TransactionModel) {
                          return TransactionTile(transaction: item);
                        }
                        return SizedBox.shrink();
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
