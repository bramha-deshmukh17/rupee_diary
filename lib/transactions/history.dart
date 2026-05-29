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
import 'transaction_tile.dart';

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
      backgroundColor: Theme.of(context).cardTheme.color,
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

  bool get isNoFilterApplied {
    if (_filter == null) return true;
    return _filter!.type == null &&
        _filter!.categoryId == null &&
        _filter!.from == null &&
        _filter!.to == null &&
        _filter!.minAmount == null &&
        _filter!.maxAmount == null &&
        _filter!.bankId == null;
  }

  Future<void> _deleteLastTransaction() async {
    final textStyle = Theme.of(context).textTheme;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          title: Text('Delete Transaction?', style: textStyle.bodyLarge),
          content: Text('Are you sure you want to delete the last transaction?', style: textStyle.bodyMedium,),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: textStyle.bodySmall?.copyWith(color: kGrey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: textStyle.bodySmall?.copyWith(color: kRed)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance.transactionsDao.deleteLastTransaction();
      if (!mounted) return;
      showSnack('Last transaction deleted', context);
      setState(() {
        page = 0;
        _transactions.clear();
        _hasMoreData = true;
      });
      _loadPageWithFilters();
    }
  }

  // Helper to pair transfer transactions (sender and receiver)
  List<dynamic> _groupTransactionsWithPairs(
    List<TransactionModel> transactions,
  ) {
    final result = <dynamic>[];
    final processedIds = <int?>{};

    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];

      // Skip if already paired
      if (processedIds.contains(tx.id)) continue;

      // Look for pair if this is a transfer
      if (tx.type.toLowerCase() == 'transfer') {
        for (int j = i + 1; j < transactions.length; j++) {
          final potentialPair = transactions[j];

          // Check if transactions form a pair
          if (potentialPair.type.toLowerCase() == 'transfer' &&
              tx.amount == potentialPair.amount &&
              tx.date.year == potentialPair.date.year &&
              tx.date.month == potentialPair.date.month &&
              tx.date.day == potentialPair.date.day &&
              tx.categoryId == potentialPair.categoryId &&
              tx.bankName != potentialPair.bankName) {
            // Found a pair - add as TransferPair
            result.add(TransferPair(sender: tx, receiver: potentialPair));
            processedIds.add(tx.id);
            processedIds.add(potentialPair.id);
            break;
          }
        }

        // If no pair found, add individually
        if (!processedIds.contains(tx.id)) {
          result.add(tx);
          processedIds.add(tx.id);
        }
      } else {
        // Non-transfer transactions
        result.add(tx);
        processedIds.add(tx.id);
      }
    }

    return result;
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
                    itemCount:
                        _groupTransactionsWithPairs(_transactions).length,
                    itemBuilder: (context, index) {
                      final item =
                          _groupTransactionsWithPairs(_transactions)[index];

                      final isSettlement = item is TransactionModel && item.category?.toLowerCase() == 'settlement';
                      final isLastTransaction = index == 0 && page == 0 && isNoFilterApplied && !isSettlement;
                      final onDoubleTap = isLastTransaction ? () => _deleteLastTransaction() : null;

                      if (item is TransferPair) {
                        return TransferTile(
                          senderTransaction: item.sender,
                          receiverTransaction: item.receiver,
                          onDoubleTap: onDoubleTap,
                        );
                      } else if (item is TransactionModel) {
                        return TransactionTile(
                          transaction: item,
                          onDoubleTap: onDoubleTap,
                          onMarkedReturned: () {
                            setState(() {
                              page = 0;
                              _transactions.clear();
                              _hasMoreData = true;
                            });
                            _loadPageWithFilters();
                          },
                        );
                      }
                      return SizedBox.shrink();
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

  final _types = const ['Income', 'Expense', 'Lend', 'Borrow', 'Transfer'];

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

  List<CategoryModel> _getFilteredCategories(String? type) {
    return _categories.where((c) {
      final n = c.name.toLowerCase();
      if (type == 'income') {
        return n == 'settlement';
      }
      return n != 'income' && n != 'lend' && n != 'borrow' && n != 'transfer';
    }).toList();
  }

  List<DropdownMenuItem<String>> _getCategoryItems() {
    final items = [
      const DropdownMenuItem(value: kAll, child: Text('All Categories')),
    ];
    final validCats = _getFilteredCategories(_f.type);
    bool found = _selCategory == kAll;
    for (final c in validCats) {
      if (c.id.toString() == _selCategory) found = true;
      items.add(DropdownMenuItem(value: c.id.toString(), child: Text(c.name)));
    }
    if (!found && _selCategory != kAll) {
      items.add(DropdownMenuItem(value: _selCategory, child: Text(_categories.isEmpty ? 'Loading...' : 'Unknown')));
    }
    return items;
  }

  List<DropdownMenuItem<String>> _getBankItems() {
    final items = [
      const DropdownMenuItem(value: kAll, child: Text('All Banks')),
    ];
    bool found = _selBank == kAll;
    for (final b in _banks) {
      if (b.id.toString() == _selBank) found = true;
      items.add(DropdownMenuItem(value: b.id.toString(), child: Text(b.name ?? 'Unnamed')));
    }
    if (!found && _selBank != kAll) {
      items.add(DropdownMenuItem(value: _selBank, child: Text(_banks.isEmpty ? 'Loading...' : 'Unknown')));
    }
    return items;
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
    final lastDate = DateTime.now();

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
        _categories = cats;
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
    final bankId = _selBank == kAll ? null : int.tryParse(_selBank);

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
                      selectedColor: kSecondaryColor,
                      backgroundColor: Theme.of(context).cardTheme.color,
                      label: Text(
                        t,
                        style: textTheme.bodyLarge?.copyWith(
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                      selected: isSelected,
                      checkmarkColor: isSelected ? Colors.white : null,
                      onSelected: (sel) {
                        setState(() {
                          final newType = sel ? t.toLowerCase() : null;
                          _f = _f.copyWith(type: newType);
                          
                          if (newType == 'lend' || newType == 'borrow' || newType == 'transfer') {
                            _selCategory = kAll;
                          } else if (_selCategory != kAll) {
                            final validCats = _getFilteredCategories(newType);
                            final exists = validCats.any((c) => c.id.toString() == _selCategory);
                            if (!exists) {
                              _selCategory = kAll;
                            }
                          }
                          
                          if (newType == 'transfer') {
                            _selBank = kAll;
                          }
                        });
                      },
                    );
                  }).toList(),
            ),
            khBox,

            // Category dropdown
            DropdownButtonFormField<String>(
              value: _selCategory,
              isExpanded: true,
              style: textTheme.bodyLarge,
              decoration: kBaseInputDecoration.copyWith(labelText: 'Category'),
              items: _getCategoryItems(),
              onChanged: (_f.type == 'lend' || _f.type == 'borrow' || _f.type == 'transfer')
                  ? null
                  : (v) => setState(() => _selCategory = v ?? kAll),
            ),
            khBox,

            // Date range
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: Icon(
                      FontAwesomeIcons.calendar,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                    ),
                    label: Text(dateLabel, style: textTheme.bodyLarge),
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
              value: _selBank,
              isExpanded: true,
              style: textTheme.bodyLarge,
              decoration: kBaseInputDecoration.copyWith(labelText: 'Bank'),
              items: _getBankItems(),
              onChanged: (_f.type == 'transfer')
                  ? null
                  : (v) {
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
                  child: Text('Clear All', style: textTheme.bodyLarge),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: kWhite,
                  ),
                  child: Text(
                    'Apply Filters',
                    style: textTheme.bodyLarge?.copyWith(color: kWhite),
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
