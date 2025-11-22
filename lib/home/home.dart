import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ReminderNotificationService.getTodayTomorrowPendingCount();
      _refreshBadge();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
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
  }

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
      appBar: Appbar(title: "", isHomePage: true, badgeCount: _badgeCount),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [khBox, BalanceCard(), khBox, TransactionsList()],
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

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});
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
          Text(
            "\$12,480.55",
            style: textTheme.headlineMedium?.copyWith(color: kWhite),
          ),
          khBox,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    FontAwesomeIcons.arrowDown,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Income\n\$4,500",
                    style: textTheme.bodyMedium?.copyWith(color: kWhite),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    FontAwesomeIcons.arrowUp,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Expenses\n\$1,250",
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

class TransactionsList extends StatelessWidget {
  const TransactionsList({super.key});
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
              Text(
                "See All",
                style: textTheme.bodyMedium?.copyWith(color: kSecondaryColor),
              ),
            ],
          ),
          khBox,
          Expanded(
            child: ListView(
              children: const [
                TransactionTile(
                  icon: FontAwesomeIcons.bagShopping,
                  iconColor: Colors.pink,
                  title: "Shopping",
                  subtitle: "Zara, New Collection",
                  amount: "-\$120.00",
                  amountColor: Colors.red,
                ),
                TransactionTile(
                  icon: FontAwesomeIcons.wallet,
                  iconColor: Colors.green,
                  title: "Salary",
                  subtitle: "Monthly Payment",
                  amount: "+\$2,500.00",
                  amountColor: Colors.green,
                ),
                TransactionTile(
                  icon: FontAwesomeIcons.youtube,
                  iconColor: Colors.orange,
                  title: "Subscription",
                  subtitle: "Netflix Premium",
                  amount: "-\$15.99",
                  amountColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;

  const TransactionTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 5.0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: textTheme.bodyLarge),
        subtitle: Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(color: kGrey),
        ),
        trailing: Text(
          amount,
          style: textTheme.bodyLarge?.copyWith(color: amountColor),
        ),
      ),
    );
  }
}
