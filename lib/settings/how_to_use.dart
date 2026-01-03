import 'package:flutter/material.dart';
import 'package:rupee_diary/utility/constant.dart';
import '../utility/appbar.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  static const String id = '/how-to-use';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const Appbar(title: 'How to use app', isBackButton: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Banks
          Text(
            '1. Add a bank account',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          _BulletItem(
            text:
                'Go to Banks → tap + to add your accounts and opening balances.',
          ),
          _BulletItem(text: 'You can add multiple bank accounts.'),
          _BulletItem(
            text: 'Long press on a bank to delete it (with safety checks).',
          ),
          _BulletItem(
            text:
                'Tap the star icon to set a bank as default for new transactions.',
          ),
          khBox,

          // 2. Transactions
          Text(
            '2. Record transactions',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          _BulletItem(
            text:
                'From Home → tap + to add an Expense, Income, Lend or Borrow.',
          ),
          _BulletItem(
            text:
                'Choose the bank, category, amount, date & time and add notes if needed.',
          ),
          _BulletItem(
            text:
                'Lend / Borrow entries can be marked as returned from the Transactions screen by long-pressing them.',
          ),
          _BulletItem(
            text:
                'When marked as returned, the app automatically creates a settlement transaction.',
          ),
          khBox,

          // 3. Budgets
          Text(
            '3. Track budgets',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          _BulletItem(
            text:
                'Open Budget → tap + to set a monthly budget for each expense category.',
          ),
          _BulletItem(
            text:
                'Budgets are month-wise, so set them again for every new month.',
          ),
          _BulletItem(
            text:
                'The Monthly Budget card shows total spent vs total budget for the month.',
          ),
          _BulletItem(
            text:
                'Each Category Budget card shows spent vs budget and remaining/over amount.',
          ),
          _BulletItem(
            text: 'Tap a budget to edit it, long-press to delete it.',
          ),
          _BulletItem(
            text:
                'Over-budget categories are highlighted in Notifications and on Home via the bell icon badge.',
          ),
          khBox,

          // 4. Bill reminders
          Text(
            '4. Set bill reminders',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          _BulletItem(
            text:
                'In Settings → Bill Reminders, tap + to add a bill with title, amount, due date, category and optional notes.',
          ),
          _BulletItem(
            text:
                'Enable "Monthly Recurring Bill" for bills that repeat every month.',
          ),
          _BulletItem(
            text: 'Reminders due today or tomorrow appear in Notifications.',
          ),
          _BulletItem(
            text:
                'From Notifications you can mark a bill as paid; recurring bills are automatically moved to the next month and rescheduled.',
          ),
          khBox,

          // 5. Statistics
          Text(
            '5. View statistics',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          _BulletItem(text: 'Open the Statistics tab from the bottom bar.'),
          _BulletItem(text: 'Top 3 categories: see where you spend the most.'),
          _BulletItem(
            text: 'Category-wise pie chart: shows expense share by category.',
          ),
          _BulletItem(
            text: 'Monthly expense bar chart: last 5 months comparison.',
          ),
          _BulletItem(
            text:
                'Budget vs Income vs Expense line chart: track trends over time.',
          ),
          _BulletItem(
            text:
                'Use the filter button to change the date range for all charts.',
          ),
          khBox,
        ],
      ),
    );
  }
}

// Simple bullet-row widget so wrapped lines align after the dot
class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: t.bodyMedium),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: t.bodyMedium)),
        ],
      ),
    );
  }
}
