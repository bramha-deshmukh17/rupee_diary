import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

import '../utility/snack.dart';
import '../db/database_helper.dart';
import '../db/model/bank.dart';
import '../db/model/transactions.dart';
import '../utility/appbar.dart';
import '../utility/constant.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  static const String id = "/transaction/history";

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TransactionModel> _transactions = [];
  int page = 0;

  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMoreData = true; //Stop trying to load if DB is empty

  String? _filterType;
  String? _filterCategory;
  DateTime? _filterFrom;
  DateTime? _filterTo;
  double? _minAmount;
  double? _maxAmount;
  int? _filterBankId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load transactions here
    _loadPageWithFilters();
  }

  //show the filters sheet to apply/remove filters
  void _showFilterSheet() async {
    final initial = TransactionFilter(
      type: _filterType,
      category: _filterCategory,
      from: _filterFrom,
      to: _filterTo,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
      bankId: _filterBankId,
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
        _filterType = result.type;
        _filterCategory = result.category;
        _filterFrom = result.from;
        _filterTo = result.to;
        _minAmount = result.minAmount;
        _maxAmount = result.maxAmount;
        _filterBankId = result.bankId;
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
      bankId: _filterBankId,
      type: _filterType,
      category: _filterCategory,
      from: _filterFrom,
      to: _filterTo,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
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

    return SafeArea(
      child: Scaffold(
        appBar: Appbar(title: 'Transactions', isBackButton: true),
        body: ModalProgressHUD(
          inAsyncCall: _isLoading,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15.0),
            child:
                _transactions.isEmpty && !_isLoading
                    ? Center(
                      child: Text(
                        'No transactions',
                        style: textTheme.bodyLarge,
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        return TransactionTile(
                          id: t.id!,
                          amount: t.amount,
                          type: t.type,
                          bankName: t.bankName,
                          date: t.date,
                          balance: t.balance,
                          category: t.category,
                          notes: t.notes,
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
      ),
    );
  }
}

//transaction tile widget to show individual transaction details
class TransactionTile extends StatelessWidget {
  final int id;
  final String type;
  final String bankName;
  final DateTime date;
  final double amount;
  final double balance;
  final String category;
  final String? notes;

  const TransactionTile({
    super.key,
    required this.id,
    required this.amount,
    required this.type,
    required this.bankName,
    required this.date,
    required this.balance,
    required this.category,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorFor = type == 'income' || type == 'borrow' ? kGreen : kRed;
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: ListTile(
        onTap: showMyDialog('Note', notes, textTheme, context),
        onLongPress: editNotesDialog(id, notes, textTheme, context),
        contentPadding: const EdgeInsets.all(10.0),
        leading: InkWell(
          borderRadius: BorderRadius.circular(24),
          child: CircleAvatar(
            backgroundColor: colorFor,
            child: Icon(
              categoryIcons[category] ?? FontAwesomeIcons.question,
              size: 15,
              color: kWhite,
            ),
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$bankName ', style: textTheme.bodyLarge),
                notes != null && notes!.isNotEmpty
                    ? Icon(
                      FontAwesomeIcons.solidMessage,
                      size: 10,
                      color: textTheme.bodySmall?.color,
                    )
                    : SizedBox.shrink(),
              ],
            ),
            SizedBox(height: 4),
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
              type == 'income' || type == 'borrow'
                  ? '+₹${amount.toStringAsFixed(2)}'
                  : '-₹${amount.toStringAsFixed(2)}',
              style: textTheme.bodyLarge?.copyWith(
                color: colorFor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text('₹${balance.toStringAsFixed(2)}', style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  //dialog to edit notes details when transaction tile is long pressed
  GestureLongPressCallback? editNotesDialog(
    int id,
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
          final _controller = TextEditingController(text: message);
          return AlertDialog(
            title: Text('Edit Note', style: textTheme.bodyLarge),
            content: TextField(
              controller: _controller,
              maxLines: 2,
              style: textTheme.bodyMedium,
              decoration: kBaseInputDecoration.copyWith(labelText: "New Note"),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancel',
                  style: textTheme.bodyLarge?.copyWith(color: kPrimaryColor),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // Save the edited note
                  try {
                    await DatabaseHelper.instance.transactionsDao.modifyNotes(
                      id,
                      _controller.text,
                    );
                    showSnack("Note updated", context);
                  } catch (e) {
                    showSnack("Failed to update note", context, error: true);
                  }
                  Navigator.pop(context);
                },
                child: Text(
                  'Save',
                  style: textTheme.bodyLarge?.copyWith(color: kPrimaryColor),
                ),
              ),
            ],
          );
        },
      );
    };
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

//helper modal class to store filter options
class TransactionFilter {
  final String? type;
  final String? category;
  final DateTime? from;
  final DateTime? to;
  final double? minAmount;
  final double? maxAmount;
  final int? bankId;

  const TransactionFilter({
    this.type,
    this.category,
    this.from,
    this.to,
    this.minAmount,
    this.maxAmount,
    this.bankId,
  });

  TransactionFilter copyWith({
    String? type,
    String? category,
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
    int? bankId,
  }) {
    return TransactionFilter(
      type: type ?? this.type,
      category: category ?? this.category,
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

  // UI-friendly selection values (use 'all' for UI -> convert to null on apply)
  String _selCategory = kAll;
  String _selBank = kAll;

  int? _bankId;
  List<Bank> _banks = [];

  final _types = const ['Income', 'Expense', 'Lend', 'Borrow'];

  @override
  void initState() {
    super.initState();
    // Initialize with initial filter values from widget
    // Set controllers and selection values according to previos set data that may contain nulls
    _f = widget.initial;
    _minCtrl.text = _f.minAmount?.toString() ?? '';
    _maxCtrl.text = _f.maxAmount?.toString() ?? '';

    _selCategory = _f.category ?? kAll;
    _bankId = _f.bankId;
    _selBank = _bankId != null ? _bankId.toString() : kAll;

    _loadBanks();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  //load bank data for bank filter dropdown
  Future<void> _loadBanks() async {
    final banks = await DatabaseHelper.instance.bankDao.getBanks();
    setState(() {
      _banks = banks;
      // keep _selBank in sync if initial bank id exists but banks loaded later
      if (_bankId != null) {
        final match = _banks.any((b) => b.id == _bankId);
        if (!match) {
          _selBank = kAll;
          _bankId = null;
        }
      }
    });
  }

  //date range picker helper to get data within selected range
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime.now(),
      initialDateRange:
          (_f.from != null && _f.to != null)
              ? DateTimeRange(start: _f.from!, end: _f.to!)
              : DateTimeRange(
                start: now.subtract(const Duration(days: 7)),
                end: now,
              ),
    );
    if (res != null) {
      setState(() {
        _f = _f.copyWith(from: res.start, to: res.end);
      });
    }
  }

  //clear all filter options
  void _clearAll() {
    setState(() {
      _f = const TransactionFilter();
      _minCtrl.clear();
      _maxCtrl.clear();
      _selCategory = kAll;
      _selBank = kAll;
      _bankId = null;
    });
  }

  //apply selected filters and return it to previous screen
  void _apply() {
    final min = double.tryParse(_minCtrl.text.trim());
    final max = double.tryParse(_maxCtrl.text.trim());
    final category = _selCategory == kAll ? null : _selCategory;
    final bankId = _selBank == kAll ? null : int.tryParse(_selBank);

    final result = TransactionFilter(
      type: _f.type,
      category: category,
      from: _f.from,
      to: _f.to,
      minAmount: min,
      maxAmount: max,
      bankId: bankId,
    );

    Navigator.pop(context, result);
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
              children: [
                for (final t in _types)
                  ChoiceChip(
                    label: Text(t),
                    selected: _f.type == t.toLowerCase(),
                    selectedColor: kSecondaryColor,
                    onSelected: (selectedType) {
                      setState(() {
                        _f = _f.copyWith(
                          type: selectedType ? t.toLowerCase() : null,
                        );
                      });
                    },
                  ),
              ],
            ),
            khBox,

            // Category dropdown
            DropdownButtonFormField<String>(
              value: _selCategory,
              isExpanded: true,
              style: textTheme.bodyLarge,
              decoration: kBaseInputDecoration.copyWith(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: kAll, child: Text('All')),
                ...categories.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
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
                    key: ValueKey(dateLabel),
                    icon: const Icon(FontAwesomeIcons.calendar),
                    label: Text(dateLabel, style: textTheme.bodyLarge),
                    onPressed: _pickRange,
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
                    style: textTheme.bodyLarge,
                    decoration: kBaseInputDecoration.copyWith(
                      labelText: 'Min amount',
                    ),
                  ),
                ),
                kwBox,
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    style: textTheme.bodyLarge,
                    decoration: kBaseInputDecoration.copyWith(
                      labelText: 'Max amount',
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
              decoration: kBaseInputDecoration.copyWith(labelText: 'Bank'),
              items: [
                const DropdownMenuItem(value: kAll, child: Text('All')),
                ..._banks.map(
                  (b) => DropdownMenuItem(
                    value: b.id.toString(),
                    child: Text(b.name!),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _selBank = v ?? kAll;
                  _bankId = (_selBank == kAll) ? null : int.tryParse(_selBank);
                  _f = _f.copyWith(bankId: _bankId);
                });
              },
            ),
            khBox,

            // Clear & Apply
            Row(
              children: [
                TextButton(
                  onPressed: _clearAll,
                  child: Text(
                    'Clear',
                    style: textTheme.bodyLarge?.copyWith(
                      color: kRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(kPrimaryColor),
                  ),
                  icon: const Icon(FontAwesomeIcons.filter, color: kWhite),
                  label: Text(
                    'Apply',
                    style: textTheme.bodyLarge?.copyWith(color: kWhite),
                  ),
                  onPressed: _apply,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
