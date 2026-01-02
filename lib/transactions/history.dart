import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

import '../utility/snack.dart';
import '../db/database_helper.dart';
import '../db/model/bank.dart';
import '../db/model/transactions.dart';
import '../db/model/category.dart';
import '../utility/appbar.dart';
import '../utility/constant.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  static const String id = "/transaction/history";

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<TransactionModel> _transactions = [];
  int page = 0;

  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMoreData = true; //Stop trying to load if DB is empty
  TransactionFilter? _filter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPageWithFilters();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  //show the filters sheet to apply/remove filters
  void _showFilterSheet() async {
    final initial = TransactionFilter(
      type: _filter?.type,
      categoryId: _filter?.categoryId,
      from: _filter?.from,
      to: _filter?.to,
      minAmount: _filter?.minAmount,
      maxAmount: _filter?.maxAmount,
      bankId: _filter?.bankId,
    );
    // filters taken from FilterSheet widget
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FilterSheet(initial: initial),
    );
    if (result != null) {
      //extract filters from result and reload data
      setState(() {
        _filter = result;
        page = 0;
        _transactions.clear();
        _hasMoreData = true;
      });
      //reload the page with give filters
      _loadPageWithFilters();
    }
  }

  //load transactions with applied filters and pagination from db
  Future<void> _loadPageWithFilters() async {
    if (_isLoading || !_hasMoreData) return;
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.transactionsDao.getFiltered(
      limit: 50,
      offset: 50 * page,
      filter: _filter,
    );
    setState(() {
      if (data.length < 50) _hasMoreData = false;
      _transactions.addAll(data);
      _isLoading = false;
    });
  }

  //helper to check the scroll position on page
  void _onScroll() {
    // Check if we are at the bottom, not currently loading, and have more data to fetch
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMoreData) {
      // Increment page and load new data
      setState(() {
        page++;
      });
      _loadPageWithFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: Appbar(title: 'Transactions', isBackButton: true),
      body: ModalProgressHUD(
        inAsyncCall: _isLoading,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15.0),
          child:
              _transactions.isEmpty && !_isLoading
                  ? Center(
                    child: Text(
                      'No transactions found.',
                      style: textTheme.bodyLarge,
                    ),
                  )
                  : ListView.builder(
                    controller: _scrollController,
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      return TransactionTile(
                        transaction: t,
                        onMarkedReturned: () {
                          setState(() {
                            page = 0;
                            _transactions.clear();
                            _hasMoreData = true;
                          });
                          _loadPageWithFilters();
                        },
                      );
                    },
                  ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterSheet,
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhite,
        shape: const CircleBorder(),
        child: const Icon(FontAwesomeIcons.filter, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// transaction tile widget to show individual transaction details
class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onMarkedReturned;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onMarkedReturned,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final type = transaction.type;
    final colorFor = type == 'income' || type == 'borrow' ? kGreen : kRed;

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
            : FontAwesomeIcons.question;

    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
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
                Text(transaction.bankName, style: textTheme.bodyLarge),
                if (transaction.notes != null && transaction.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      FontAwesomeIcons.solidMessage,
                      size: 10,
                      color: textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy • hh:mm:ss').format(transaction.date),
              style: textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              type == 'income' || type == 'borrow'
                  ? '+₹${transaction.amount.toStringAsFixed(2)}'
                  : '-₹${transaction.amount.toStringAsFixed(2)}',
              style: textTheme.bodyLarge?.copyWith(
                color: colorFor,
                fontWeight: FontWeight.bold,
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
    return () {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text('Mark as Returned', style: textTheme.bodyLarge),
              content: Text(
                transaction.type == 'lend'
                    ? 'Mark this loan as returned? This will add an income entry.'
                    : 'Mark this borrow as returned? This will add an expense entry.',
                style: textTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: textTheme.bodyLarge),
                ),
                isReturned(transaction.notes)
                    ? TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Already Returned',
                        style: textTheme.bodyLarge?.copyWith(color: kGrey),
                      ),
                    )
                    : TextButton(
                      onPressed: () async {
                        try {
                          await markTransaction();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          showSnack('Marked as returned', context);
                          onMarkedReturned();
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
            ),
      );
    };
  }

  // Function to mark the transaction as returned
  Future<void> markTransaction() async {
    // Fetch the bank id needed for insert
    final rows = await DatabaseHelper.instance.transactionsDao.database.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    final bankId = rows.isNotEmpty ? rows.first['bankId'] as int : null;
    if (bankId == null) {
      throw Exception('Bank not found for transaction');
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
    final data = banks.firstWhere((b) => b.id == bankId);

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
      'bankId': bankId,
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

//helper modal class to store filter options
class TransactionFilter {
  final String? type;
  final int? categoryId;
  final DateTime? from;
  final DateTime? to;
  final double? minAmount;
  final double? maxAmount;
  final int? bankId;

  const TransactionFilter({
    this.type,
    this.categoryId,
    this.from,
    this.to,
    this.minAmount,
    this.maxAmount,
    this.bankId,
  });

  TransactionFilter copyWith({
    String? type,
    int? categoryId,
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
    int? bankId,
  }) {
    return TransactionFilter(
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      from: from ?? this.from,
      to: to ?? this.to,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      bankId: bankId ?? this.bankId,
    );
  }
}

//modal bottom sheet widget to show filter options
class FilterSheet extends StatefulWidget {
  final TransactionFilter initial;
  const FilterSheet({super.key, required this.initial});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  static const String kAll = 'all';

  late TransactionFilter _f;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  // Store category selection as id string (e.g. "1"), not name
  String _selCategory = kAll;
  // String selected in the dropdown (bank id as String or 'all')
  String _selBank = kAll;

  List<BankModel> _banks = [];

  //list of categories loaded from db for category filter dropdown
  List<CategoryModel> _categories = [];

  final _types = const ['Income', 'Expense', 'Lend', 'Borrow'];

  @override
  void initState() {
    super.initState();
    _f = widget.initial;

    _minCtrl.text = _f.minAmount?.toString() ?? '';
    _maxCtrl.text = _f.maxAmount?.toString() ?? '';

    _selCategory = _f.categoryId != null ? _f.categoryId.toString() : kAll;
    _selBank = _f.bankId != null ? _f.bankId.toString() : kAll;

    _loadBanks();
    _loadCategories();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

    Future<void> _pickRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 5);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange:
          (_f.from != null && _f.to != null)
              ? DateTimeRange(start: _f.from!, end: _f.to!)
              : null,
    );

    if (picked != null) {
      setState(() {
        _f = _f.copyWith(from: picked.start, to: picked.end);
      });
    }
  }

  //load bank data for bank filter dropdown
    Future<void> _loadBanks() async {
    try {
      final banks = await DatabaseHelper.instance.bankDao.getBanks();
      setState(() {
        _banks = banks;

        // if currently selected bank id no longer exists, reset to "all"
        if (_selBank != kAll) {
          final selId = int.tryParse(_selBank);
          final exists = selId != null && _banks.any((b) => b.id == selId);
          if (!exists) {
            _selBank = kAll;
          }
        }
      });
    } catch (_) {
      showSnack('Failed to load banks', context, error: true);
    }
  }

  //load category data from db for category filter dropdown
  Future<void> _loadCategories() async {
    try {
      final cats = await DatabaseHelper.instance.categoryDao.getAllCategories();
      setState(() {
        //exclude Income, Lend, Borrow categories from filter options
        _categories =
            cats.where((c) {
              final n = c.name.toLowerCase();
              return n != 'income' && n != 'lend' && n != 'borrow';
            }).toList();
      });
    } catch (_) {
      showSnack('Failed to load categories', context, error: true);
    }
  }

  //date range picker helper to get data within selected range
    void _apply() {
    final min = double.tryParse(_minCtrl.text.trim());
    final max = double.tryParse(_maxCtrl.text.trim());
    final categoryId = _selCategory == kAll ? null : int.tryParse(_selCategory);
    final bankId =
        _selBank == kAll ? null : int.tryParse(_selBank);

    final result = TransactionFilter(
      type: _f.type,
      categoryId: categoryId,
      from: _f.from,
      to: _f.to,
      minAmount: min,
      maxAmount: max,
      bankId: bankId,
    );

    Navigator.pop(context, result);
  }

  //clear all filter options
  void _clearAll() {
    setState(() {
      _f = const TransactionFilter();
      _minCtrl.clear();
      _maxCtrl.clear();
      _selCategory = kAll;
      _selBank = kAll;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateLabel =
        (_f.from == null || _f.to == null)
            ? 'Date range'
            : '${DateFormat('dd/MM/yy').format(_f.from!)} - ${DateFormat('dd/MM/yy').format(_f.to!)}';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filter Transactions', style: textTheme.headlineMedium),
            khBox,
            // Type chips
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Type', style: textTheme.bodyMedium),
            ),
            Wrap(
              spacing: 8,
              children:
                  _types.map((t) {
                    final isSelected = _f.type == t.toLowerCase();
                    return ChoiceChip(
                      label: Text(t),
                      selected: isSelected,
                      onSelected: (sel) {
                        setState(() {
                          _f = _f.copyWith(type: sel ? t.toLowerCase() : null);
                        });
                      },
                    );
                  }).toList(),
            ),
            khBox,

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: _selCategory,
              isExpanded: true,
              style: textTheme.bodyLarge,
              decoration: kBaseInputDecoration.copyWith(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                  value: kAll,
                  child: Text('All Categories'),
                ),
                //build category list from db so filter options always match actual data
                ..._categories.map(
                  (c) => DropdownMenuItem(
                    value: c.id.toString(),
                    child: Text(c.name),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selCategory = v ?? kAll),
            ),
            khBox,

            // Date range
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(FontAwesomeIcons.calendar),
                    label: Text(dateLabel),
                  ),
                ),
              ],
            ),
            khBox,

            // Amount range
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: kBaseInputDecoration.copyWith(
                      labelText: 'Min Amount',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: kBaseInputDecoration.copyWith(
                      labelText: 'Max Amount',
                    ),
                  ),
                ),
              ],
            ),
            khBox,

            // Bank dropdown
            DropdownButtonFormField<String>(
              initialValue: _selBank,
              isExpanded: true,
              style: textTheme.bodyLarge,
              decoration: kBaseInputDecoration.copyWith(labelText: 'Bank'),
              items: [
                const DropdownMenuItem(value: kAll, child: Text('All Banks')),
                ..._banks.map(
                  (b) => DropdownMenuItem(
                    value: b.id.toString(),
                    child: Text(b.name ?? 'Unnamed'),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _selBank = v ?? kAll);
              },
            ),
            khBox,

            // Clear & Apply
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Clear All'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: kWhite,
                  ),
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
