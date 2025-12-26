import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../db/model/transactions.dart';
import '../transactions/history.dart';
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
  // ignore: unused_field
  bool _alive = true;
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
        totalBalance = usage['total_balance'];
        totalIncome = usage['total_income'];
        totalExpense = usage['total_expense'];
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
    _alive = false;
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
      final c =
          await ReminderNotificationService.getTodayTomorrowPendingCount();
      if (!mounted) return;
      setState(() => _badgeCount = c);
    } catch (e) {
      if (!mounted) return;

      showSnack('Failed to refresh reminders', context, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: "Home", appbarIcons: true, badgeCount: _badgeCount),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
          Text(
            "₹${balance.toStringAsFixed(2)}",
            style: textTheme.headlineMedium?.copyWith(color: kWhite),
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
                  Text(
                    "Income\n₹${income.toStringAsFixed(2)}",
                    style: textTheme.bodyMedium?.copyWith(color: kWhite),
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
                  Text(
                    "Expenses\n₹${expense.toStringAsFixed(2)}",
                    style: textTheme.bodyMedium?.copyWith(color: kWhite),
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
                      itemCount: transactions!.length,
                      itemBuilder: (context, index) {
                        final data = transactions![index];
                        // Simply pass the model object
                        return TransactionTile(transaction: data);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

//each transaction tile design
class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final type = transaction.type;
    final amount = transaction.amount;
    final notes = transaction.notes;
    final balance = transaction.balance;
    final category = transaction.category;
    final bankName = transaction.bankName;
    final DateTime date = transaction.date;

    final iconCodePoint = transaction.iconCodePoint;
    final iconFontFamily = transaction.iconFontFamily;
    final iconFontPackage = transaction.iconFontPackage;

    final colorFor = (type == 'income' || type == 'borrow') ? kGreen : kRed;

    //use icon data coming from db, fallback to a generic icon if not present
    final IconData iconData =
        (iconCodePoint != null)
            ? IconData(
              iconCodePoint,
              fontFamily: iconFontFamily,
              fontPackage: iconFontPackage,
            )
            : FontAwesomeIcons.question;

    return GestureDetector(
      onTap: showMyDialog('Note', notes, textTheme, context),
      child: Card(
        elevation: 5,
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        child: ListTile(
          contentPadding: const EdgeInsets.all(10.0),
          leading: GestureDetector(
            onTap: showMyDialog('Category', category, textTheme, context),
            child: CircleAvatar(
              backgroundColor: colorFor,
              child: Icon(iconData, size: 15, color: kWhite),
            ),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$bankName ', style: textTheme.bodyLarge),
                  if (notes != null && notes.isNotEmpty)
                    Icon(
                      FontAwesomeIcons.solidMessage,
                      size: 10,
                      color: textTheme.bodySmall?.color,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy • hh:mm:ss').format(date),
                style: textTheme.bodySmall,
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (type == 'income' || type == 'borrow')
                    ? '+₹${amount.toStringAsFixed(2)}'
                    : '-₹${amount.toStringAsFixed(2)}',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorFor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // If your model has a balance field, use it here.
              // Otherwise, you might want to hide this Text widget.
              Text(balance.toStringAsFixed(2), style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to show dialog to show notes and category of transaction in alert dialog
  GestureTapCallback? showMyDialog(
    String title,
    String? message,
    TextTheme textTheme,
    BuildContext context,
  ) {
    if (message == null || message.isEmpty) {
      return null;
    }
    return () {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title, style: textTheme.bodyLarge),
            content: Text(message, style: textTheme.bodyMedium),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Close',
                  style: textTheme.bodyLarge?.copyWith(color: kPrimaryColor),
                ),
              ),
            ],
          );
        },
      );
    };
  }
}
