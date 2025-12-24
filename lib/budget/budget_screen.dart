import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../utility/constant.dart';
import '../utility/appbar.dart';
import '../utility/bottombar.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  static const String id = "/budget";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: 'Budget', isBackButton: false),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Column(
          children: [
            // Monthly card takes its natural height
            const MonthlyBudgetSection(),
            khBox,
            // Category list takes the remaining height
            Expanded(child: const CategoryBudgetSection()),
          ],
        ),
      ),
      bottomNavigationBar: const BottomBar(currentIndex: 2),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhite,
        shape: const CircleBorder(),
        child: const Icon(FontAwesomeIcons.plus, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class MonthlyBudgetSection extends StatelessWidget {
  const MonthlyBudgetSection({super.key});

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
            "₹1000",
            style: textTheme.displayLarge?.copyWith(
              fontSize: 50.0,
              fontWeight: FontWeight.bold,
              color: kWhite,
            ),
          ),
          Text(
            "of ₹2000 spent",
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
  const CategoryBudgetSection({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Because the parent wraps this widget in Expanded, we are allowed to use
    // a Column with an Expanded ListView here.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Category Budgets", style: textTheme.headlineMedium),
        khBox,
        // ListView must be inside Expanded to receive bounded height
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: const [
              CategoryBudgetCard(
                icon: FontAwesomeIcons.bagShopping,
                title: "Shopping",
                spent: 380,
                total: 500,
              ),
              CategoryBudgetCard(
                icon: FontAwesomeIcons.cartShopping,
                title: "Groceries",
                spent: 415,
                total: 400,
              ),
              CategoryBudgetCard(
                icon: FontAwesomeIcons.tv,
                title: "Entertainment",
                spent: 110,
                total: 200,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// keep your existing CategoryBudgetCard (unchanged)

class CategoryBudgetCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double spent;
  final double total;

  const CategoryBudgetCard({
    super.key,
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
