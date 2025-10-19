import 'package:flutter/material.dart';

class TransactionsList extends StatelessWidget {
  const TransactionsList({super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Recent Transactions",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "See All",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: const [
                TransactionTile(
                  icon: Icons.shopping_bag,
                  iconColor: Colors.pink,
                  title: "Shopping",
                  subtitle: "Zara, New Collection",
                  amount: "-\$120.00",
                  amountColor: Colors.red,
                ),
                TransactionTile(
                  icon: Icons.account_balance_wallet,
                  iconColor: Colors.green,
                  title: "Salary",
                  subtitle: "Monthly Payment",
                  amount: "+\$2,500.00",
                  amountColor: Colors.green,
                ),
                TransactionTile(
                  icon: Icons.subscriptions,
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        trailing: Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
      ),
    );
  }
}