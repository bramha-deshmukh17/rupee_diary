import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../utility/appbar.dart';
import '../utility/bottombar.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';
import './spending_graph.dart';
import './line_graph.dart';

class StatisticsFilter {
  final DateTime? from;
  final DateTime? to;

  const StatisticsFilter({this.from, this.to});

  StatisticsFilter copyWith({DateTime? from, DateTime? to}) {
    return StatisticsFilter(from: from ?? this.from, to: to ?? this.to);
  }
}

class StatisticsScreen extends StatefulWidget {
  static const String id = '/statistics';
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatisticsFilter _filter = const StatisticsFilter();

  @override
  void initState() {
    super.initState();
    _filter = const StatisticsFilter(from: null, to: null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: 'Statistics'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopSpendingSection(filter: _filter),
              khBox,
              CategoryExpensePieSection(filter: _filter),
              khBox,
              const SpendingBarChart(),
              khBox,
              BudgetVsIncomeExpenseLineSection(),
            ],
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
      bottomNavigationBar: const BottomBar(currentIndex: 1),
    );
  }

  Future<void> _showFilterSheet() async {
    final initial = _filter;

    final result = await showModalBottomSheet<StatisticsFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FilterSheet(initial: initial),
    );

    if (result != null) {
      setState(() {
        _filter = result;
      });
    }
  }
}

//====================================Filter sheet============================
class FilterSheet extends StatefulWidget {
  final StatisticsFilter initial;
  const FilterSheet({super.key, required this.initial});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late StatisticsFilter _f;

  // month dropdown (past months, excluding current)
  late final List<DateTime> _monthOptions;
  DateTime? _selectedMonthStart;

  @override
  void initState() {
    super.initState();
    _f = widget.initial;

    final now = DateTime.now();
    // last 12 months, excluding current month
    _monthOptions = List.generate(12, (i) {
      final m = DateTime(now.year, now.month - (i + 1), 1);
      return m;
    });

    // if existing filter range exactly matches a month in our options, pre‑select it
    if (_f.from != null && _f.to != null) {
      for (final m in _monthOptions) {
        final start = DateTime(m.year, m.month, 1);
        final end = DateTime(m.year, m.month + 1, 0, 23, 59, 59, 999);
        if (_sameDay(_f.from!, start) && _sameMoment(_f.to!, end)) {
          _selectedMonthStart = m;
          break;
        }
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _sameMoment(DateTime a, DateTime b) => a.isAtSameMomentAs(b);

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
        _selectedMonthStart = null; // custom range overrides month dropdown
        _f = _f.copyWith(from: res.start, to: res.end);
      });
    }
  }

  void _onMonthChanged(DateTime? monthStart) {
    setState(() {
      _selectedMonthStart = monthStart;
      if (monthStart == null) {
        // clear month, keep existing range as-is
        return;
      }
      final start = DateTime(monthStart.year, monthStart.month, 1);
      final end = DateTime(
        monthStart.year,
        monthStart.month + 1,
        0,
        23,
        59,
        59,
        999,
      );
      _f = _f.copyWith(from: start, to: end);
    });
  }

  void _clearAll() {
    setState(() {
      _selectedMonthStart = null;
      // explicit type:null so default in DAO becomes "last 30 days" instead of current month
      _f = const StatisticsFilter(from: null, to: null);
    });
  }

  void _apply() {
    Navigator.pop(context, _f);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateLabel =
        (_f.from == null || _f.to == null)
            ? 'Date range'
            : '${DateFormat('dd/MM/yy').format(_f.from!)} - '
                '${DateFormat('dd/MM/yy').format(_f.to!)}';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Filter Statistics', style: textTheme.headlineMedium),
          khBox,

          // Month dropdown (past months, excluding current)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Month (past months)', style: textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<DateTime?>(
            value: _selectedMonthStart,
            isExpanded: true,
            decoration: kBaseInputDecoration.copyWith(
              labelText: 'Select month',
            ),
            items: [
              const DropdownMenuItem<DateTime?>(
                value: null,
                child: Text('None (use date range / default)'),
              ),
              ..._monthOptions.map(
                (m) => DropdownMenuItem<DateTime?>(
                  value: m,
                  child: Text(DateFormat('MMM yyyy').format(m)),
                ),
              ),
            ],
            onChanged: _onMonthChanged,
          ),
          khBox,

          // Date range
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Date range', style: textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
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

          // Clear & Apply
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _clearAll,
                child: Text(
                  'Clear All',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              kwBox,
              ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: kWhite,
                ),
                child: Text(
                  'Apply Filters',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//====================================Top Spending============================

class TopSpendingSection extends StatefulWidget {
  final StatisticsFilter filter;
  const TopSpendingSection({super.key, required this.filter});

  @override
  State<TopSpendingSection> createState() => _TopSpendingSectionState();
}

class _TopSpendingSectionState extends State<TopSpendingSection> {
  List<Map<String, dynamic>> topSpendingList = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTopSpending();
  }

  @override
  void didUpdateWidget(covariant TopSpendingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter != oldWidget.filter) {
      _loadTopSpending();
    }
  }

  Future<void> _loadTopSpending() async {
    setState(() => _loading = true);
    try {
      final result = await DatabaseHelper.instance.transactionsDao
          .getTopSpendingCategoryForStats(widget.filter);
      if (!mounted) return;
      setState(() => topSpendingList = result);
    } catch (e) {
      if (mounted) {
        showSnack('Failed to load top spendings', context, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top 3 categories',
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        khBox,
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (topSpendingList.isEmpty)
          Text(
            'No expense data for given period',
            style: textTheme.bodyMedium,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topSpendingList.length,
            itemBuilder: (context, index) {
              final item = topSpendingList[index];
              final iconCodePoint = item['icon_code_point'] as int?;
              final iconFontFamily = item['icon_font_family'] as String?;
              final iconPackage = item['icon_font_package'] as String?;
              final title = item['category'] as String? ?? 'Unknown';
              final spent = (item['totalSpending'] as num?)?.toDouble() ?? 0.0;

              return _spendingItem(
                icon:
                    (iconCodePoint != null && iconFontFamily != null)
                        ? IconData(
                          iconCodePoint,
                          fontFamily: iconFontFamily,
                          fontPackage: iconPackage,
                        )
                        : Icons.category,
                title: title,
                spent: spent,
                textTheme: textTheme,
              );
            },
          ),
      ],
    );
  }

  Widget _spendingItem({
    required IconData icon,
    required String title,
    required double spent,
    required TextTheme textTheme,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryColor.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: kPrimaryColor, size: 20),
            ),
            kwBox,
            Expanded(
              child: Text(
                title,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '₹${spent.toStringAsFixed(2)}',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryExpensePieSection extends StatefulWidget {
  final StatisticsFilter filter;
  const CategoryExpensePieSection({super.key, required this.filter});

  @override
  State<CategoryExpensePieSection> createState() =>
      _CategoryExpensePieSectionState();
}

class _CategoryExpensePieSectionState extends State<CategoryExpensePieSection> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = false;
  int? _touchedIndex;

  // fixed color palette for pie sections
  static const List<Color> _sectionColors = [
    Color(0xFF1ABC9C),
    Color(0xFF3498DB),
    Color(0xFFE67E22),
    Color(0xFFE74C3C),
    Color(0xFF9B59B6),
    Color(0xFF2ECC71),
    Color(0xFFF1C40F),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant CategoryExpensePieSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter != oldWidget.filter) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final rows = await DatabaseHelper.instance.transactionsDao
          .getCategoryExpenseForStats(widget.filter);
      if (!mounted) return;
      setState(() => _data = rows);
    } catch (_) {
      if (mounted) {
        showSnack('Failed to load category stats', context, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No expense data for any category in given period',
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }

    final total = _data.fold<double>(
      0,
      (p, e) => p + ((e['totalExpense'] as num?)?.toDouble() ?? 0.0),
    );

    if (total <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No expense data for any category in selected period',
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }

    // build slices with fixed colors + percentages
    final slices = List<_CategorySlice>.generate(_data.length, (i) {
      final row = _data[i];
      final value = (row['totalExpense'] as num?)?.toDouble() ?? 0.0;
      final percent = total == 0 ? 0.0 : (value / total * 100);
      final name = row['category']?.toString() ?? '';
      final color = _sectionColors[i % _sectionColors.length];
      return _CategorySlice(
        name: name,
        value: value,
        percent: percent,
        color: color,
      );
    });

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category-wise expense',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            khBox,
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        setState(() => _touchedIndex = null);
                        return;
                      }
                      setState(() {
                        _touchedIndex =
                            pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                      });
                    },
                  ),
                  sections:
                      slices
                          .map(
                            (s) => PieChartSectionData(
                              value: s.value,
                              color: s.color,
                              title:
                                  ' ${s.percent.toStringAsFixed(0)}%', // label on slice
                              radius: 70,
                              titleStyle: textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
            khBox,
            // legend: one entry per category with matching color
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  slices.map((s) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${s.name} (${s.percent.toStringAsFixed(0)}%)',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySlice {
  final String name;
  final double value;
  final double percent;
  final Color color;

  const _CategorySlice({
    required this.name,
    required this.value,
    required this.percent,
    required this.color,
  });
}
