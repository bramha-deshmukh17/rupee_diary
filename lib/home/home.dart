import 'package:flutter/material.dart';
import 'package:rupee_diary/utility/constant.dart';
import '../services/route_observer.dart';
import '../utility/appbar.dart';
import '../services/reminder_notification.dart';
import '../utility/bottombar.dart';
import '../utility/snack.dart';
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
     try {

      final c = await ReminderNotificationService.getTodayTomorrowPendingCount();
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
      bottomNavigationBar: BottomBar(currentIndex: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: kPrimaryColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
