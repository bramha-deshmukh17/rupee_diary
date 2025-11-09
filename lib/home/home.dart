import 'package:flutter/material.dart';
import 'package:rupee_diary/utility/constant.dart';
import '../services/route_observer.dart';
import '../utility/appbar.dart';
import '../services/reminder_notification.dart';
import 'balance_card.dart';
import 'transactions_list.dart';

class HomeScreen extends StatefulWidget {
  static const String id = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware  {
  int _badgeCount = 0;
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
      routeObserver.subscribe(this, route); // no cast
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this); // no cast
    _alive = false;
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshBadge(); // refresh when returning to Home
  }

  Future<void> _refreshBadge() async {
    final c = await ReminderNotificationService.getTodayTomorrowPendingCount();
    if (!mounted) return;
    setState(() => _badgeCount = c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: "Name", isHomePage: true, badgeCount: _badgeCount),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [khBox, BalanceCard(), khBox, TransactionsList()],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.home, color: Colors.deepOrange),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.bar_chart, color: Colors.grey),
              onPressed: () {},
            ),
            SizedBox(width: 40),
            IconButton(
              icon: Icon(Icons.wallet, color: Colors.grey),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.category, color: Colors.grey),
              onPressed: () {},
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.deepOrange,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
