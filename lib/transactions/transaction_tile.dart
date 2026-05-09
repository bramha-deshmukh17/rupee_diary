import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../db/model/transactions.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

// Helper class to hold paired transfer transactions
class TransferPair {
  final TransactionModel sender;
  final TransactionModel receiver;

  TransferPair({required this.sender, required this.receiver});
}

// Separate card for transfer transactions showing both banks
class TransferTile extends StatelessWidget {
  final TransactionModel senderTransaction;
  final TransactionModel receiverTransaction;

  const TransferTile({
    super.key,
    required this.senderTransaction,
    required this.receiverTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amount = senderTransaction.amount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with transfer icon and date
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: kGrey,
                  child: Icon(
                    FontAwesomeIcons.arrowRightArrowLeft,
                    color: kWhite,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'dd/MM/yyyy • hh:mm a',
                        ).format(senderTransaction.date),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: textTheme.bodyLarge?.copyWith(
                    color: kGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Sender bank
            Row(
              children: [
                Icon(FontAwesomeIcons.arrowLeft, size: 14, color: kRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: textTheme.bodySmall?.copyWith(color: kGrey),
                      ),
                      Text(
                        senderTransaction.bankName,
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                Text(
                  '-₹${amount.toStringAsFixed(2)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: kRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Receiver bank
            Row(
              children: [
                Icon(FontAwesomeIcons.arrowRight, size: 14, color: kGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To',
                        style: textTheme.bodySmall?.copyWith(color: kGrey),
                      ),
                      Text(
                        receiverTransaction.bankName,
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                Text(
                  '+₹${amount.toStringAsFixed(2)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: kGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Transaction tile widget to show individual transaction details
class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onMarkedReturned;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onMarkedReturned,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final type = transaction.type;
    final colorFor =
        type == 'income' || type == 'borrow'
            ? kGreen
            : type == 'transfer'
            ? kSecondaryColor
            : kRed;

    final iconCodePoint = transaction.iconCodePoint;
    final iconFontFamily = transaction.iconFontFamily;
    final iconFontPackage = transaction.iconFontPackage;

    //use icon info coming from db, fallback to a generic icon if not present
    final IconData iconData =
        (iconCodePoint != null)
            ? IconData(
              iconCodePoint,
              fontFamily: iconFontFamily,
              fontPackage: iconFontPackage,
            )
            : type == 'transfer'
            ? FontAwesomeIcons.arrowRightArrowLeft
            : FontAwesomeIcons.question;

    return Card(
      child: ListTile(
        onTap: showMyDialog('Note', transaction.notes, textTheme, context),
        onLongPress:
            (type == 'lend' || type == 'borrow')
                ? _markAsReturnedDialog(textTheme: textTheme, context: context)
                : null,
        contentPadding: const EdgeInsets.all(10.0),

        leading: GestureDetector(
          onTap: showMyDialog(
            'Category',
            transaction.category,
            textTheme,
            context,
          ),
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
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      transaction.bankName,
                      style: textTheme.bodyLarge,
                    ),
                  ),
                ),

                if (transaction.notes != null && transaction.notes!.isNotEmpty)
                  Icon(
                    FontAwesomeIcons.solidMessage,
                    size: 10,
                    color: textTheme.bodySmall?.color,
                  ),
              ],
            ),

            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy • hh:mm a').format(transaction.date),
              style: textTheme.bodySmall,
            ),
          ],
        ),

        trailing: SizedBox(
          width: MediaQuery.of(context).size.width * 0.3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  type == 'income' || type == 'borrow'
                      ? '+₹${transaction.amount.toStringAsFixed(2)}'
                      : '-₹${transaction.amount.toStringAsFixed(2)}',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorFor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${transaction.balance.toStringAsFixed(2)}',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  //dialog to show notes or category details when transaction tile is tapped
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
            backgroundColor: Theme.of(context).cardTheme.color,
            shadowColor: Theme.of(context).cardTheme.shadowColor,
            title: Text(
              title,
              style: textTheme.bodyLarge?.copyWith(color: kPrimaryColor),
            ),
            content: Text(message, style: textTheme.bodyMedium),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: textTheme.bodyLarge),
              ),
            ],
          );
        },
      );
    };
  }

  // Long-press handler to mark lend/borrow as returned
  GestureLongPressCallback _markAsReturnedDialog({
    required TextTheme textTheme,
    required BuildContext context,
  }) {
    return () async {
      if (isReturned(transaction.notes)) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            shadowColor: Theme.of(context).cardTheme.shadowColor,
            title: Text('Mark as Returned', style: textTheme.bodyLarge),
            content: Text(
              'Already Returned',
              style: textTheme.bodyMedium?.copyWith(color: kGrey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: textTheme.bodyLarge),
              ),
            ],
          ),
        );
        return;
      }

      final banks = await DatabaseHelper.instance.bankDao.getBanks();
      final rows = await DatabaseHelper.instance.transactionsDao.database.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      final originalBankId = rows.isNotEmpty ? rows.first['bankId'] as int? : null;
      int? selectedBankId = originalBankId;

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: Theme.of(context).cardTheme.color,
                shadowColor: Theme.of(context).cardTheme.shadowColor,
                title: Text('Mark as Returned', style: textTheme.bodyLarge),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.type == 'lend'
                          ? 'Mark this lend as returned? This will add an income entry.'
                          : 'Mark this borrow as returned? This will add an expense entry.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text('Select Settlement Bank:', style: textTheme.bodySmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedBankId,
                      isExpanded: true,
                      style: textTheme.bodyLarge,
                      decoration: kBaseInputDecoration,
                      items: banks.map((b) {
                        return DropdownMenuItem<int>(
                          value: b.id,
                          child: Text(b.name ?? 'Unnamed'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => selectedBankId = v);
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: textTheme.bodyLarge),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (selectedBankId == null) return;
                      try {
                        await markTransaction(selectedBankId!);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        showSnack('Marked as returned', context);
                        onMarkedReturned?.call();
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        showSnack(
                          'Failed to mark as returned',
                          context,
                          error: true,
                        );
                      }
                    },
                    child: Text(
                      'Confirm',
                      style: textTheme.bodyLarge?.copyWith(color: kGreen),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    };
  }

  // Function to mark the transaction as returned
  Future<void> markTransaction(int selectedBankId) async {
    // Fetch the bank id needed for insert
    final rows = await DatabaseHelper.instance.transactionsDao.database.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    if (rows.isEmpty) {
      throw Exception('Transaction not found');
    }

    // Build the appended note (preserve existing)
    final prevNotes = rows.first['notes'] as String?;

    // Create a "return" transaction:
    final returnType = (transaction.type == 'lend') ? 'income' : 'expense';
    final now = DateTime.now();

    final banks = await DatabaseHelper.instance.bankDao.getBanks();
    if (banks.isEmpty) {
      throw Exception('No banks found');
    }
    final data = banks.firstWhere((b) => b.id == selectedBankId);

    // bank's balance after transaction (will be computed in DAO, but kept here if needed elsewhere)
    double balance = data.balance!;
    final amount = rows.first['amount']! as num;
    switch (transaction.type.toLowerCase()) {
      case 'borrow':
        balance += amount;
        break;
      case 'lend':
        balance -= amount;
        break;
      default:
        break;
    }

    //get category id for Settlement from db so that it stays in sync with categories table
    final settlementCategoryId = await DatabaseHelper.instance.categoryDao
        .getIdByName('Settlement');
    if (settlementCategoryId == null) {
      throw Exception('Settlement category not found in database');
    }

    final tx = {
      'bankId': selectedBankId,
      'amount': amount,
      'type': returnType,
      'balance': balance,
      'categoryId': settlementCategoryId,
      'date': now.toIso8601String(),
      'notes':
          'Return of ${transaction.type} on ${DateFormat('dd/MM/yy').format(transaction.date)}${prevNotes == null || prevNotes.isEmpty ? '' : ' \n$prevNotes'}',
    };

    await DatabaseHelper.instance.transactionsDao.insertTransaction(tx);

    final tempNote =
        (prevNotes == null || prevNotes.isEmpty)
            ? 'returned'
            : '$prevNotes - returned';
    // Append note on original txn (safe concat even if notes were NULL)
    await DatabaseHelper.instance.transactionsDao.database.rawUpdate(
      '''
        update transactions
        set notes = ?
        where id = ?
      ''',
      [
        tempNote, // append  returned message
        transaction.id,
      ],
    );
  }

  // check if transaction is already marked as returned
  bool isReturned(String? notes) {
    if (notes == null) {
      return false;
    }
    return notes.toLowerCase().contains('returned');
  }
}
