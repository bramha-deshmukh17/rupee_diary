import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

class BudgetVsIncomeExpenseLineSection extends StatefulWidget {
  const BudgetVsIncomeExpenseLineSection({super.key});

  @override
  State<BudgetVsIncomeExpenseLineSection> createState() =>
      _BudgetVsIncomeExpenseLineSectionState();
}

class _BudgetVsIncomeExpenseLineSectionState
    extends State<BudgetVsIncomeExpenseLineSection> {
  bool _loading = false;
  List<_MonthLinePoint> _points = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final txDao = DatabaseHelper.instance.transactionsDao;
      final budDao = DatabaseHelper.instance.budgetDao;

      final rows = await txDao.getLastFiveMonthsStats();

      // Map DB rows by monthStart string -> (income, expense)
      final byMonth = <String, Map<String, double>>{};
      for (final r in rows) {
        final mStr = r['monthStart'] as String;
        double toDouble(Object? v) {
          if (v == null) return 0.0;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString()) ?? 0.0;
        }

        byMonth[mStr] = {
          'income': toDouble(r['totalIncome']),
          'expense': toDouble(r['totalExpense']),
        };
      }

      final now = DateTime.now();
      final List<_MonthLinePoint> pts = [];
      for (int i = 4; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final key =
            '${month.year.toString().padLeft(4, '0')}-'
            '${month.month.toString().padLeft(2, '0')}-01';

        final row = byMonth[key] ?? const {'income': 0.0, 'expense': 0.0};

        // fetch budget for this specific month
        final budgetForMonth = await budDao.getTotalBudgetAmount(
          month.year,
          month.month,
        );

        pts.add(
          _MonthLinePoint(
            month: month,
            income: row['income'] ?? 0.0,
            expense: row['expense'] ?? 0.0,
            budget: budgetForMonth,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _points = pts;
      });
    } catch (_) {
      if (mounted) {
        showSnack(
          'Failed to load 5-month budget statistics',
          context,
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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

    if (_points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No data for last 5 months', style: textTheme.bodyMedium),
        ),
      );
    }

    double maxY = 0;
    for (final p in _points) {
      maxY = [
        maxY,
        p.income,
        p.expense,
        p.budget,
      ].reduce((a, b) => a > b ? a : b);
    }
    if (maxY <= 0) maxY = 1;
    maxY *= 1.4; // some headroom

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget vs Income vs Expense',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            khBox,
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,

                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: kSecondaryColor),
                      left: BorderSide(color: kSecondaryColor),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          // only label integer x values (0.._points.length-1)
                          if (value % 1 != 0) return const SizedBox.shrink();
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _points.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              DateFormat('MMM').format(_points[idx].month),
                              style: textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) {
                          if (value < 0) return const SizedBox.shrink();
                          return Text(
                            value.toStringAsFixed(0),
                            style: textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    // Budget (same value each month)
                    LineChartBarData(
                      spots: List.generate(
                        _points.length,
                        (i) => FlSpot(i.toDouble(), _points[i].budget),
                      ),
                      color: kPrimaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                    // Income
                    LineChartBarData(
                      spots: List.generate(
                        _points.length,
                        (i) => FlSpot(i.toDouble(), _points[i].income),
                      ),
                      color: kGreen,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                    // Expense
                    LineChartBarData(
                      spots: List.generate(
                        _points.length,
                        (i) => FlSpot(i.toDouble(), _points[i].expense),
                      ),
                      color: kRed,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            khBox,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _legendDot(color: kPrimaryColor),
                const SizedBox(width: 4),
                Text('Budget', style: textTheme.bodySmall),
                kwBox,
                _legendDot(color: kGreen),
                const SizedBox(width: 4),
                Text('Income', style: textTheme.bodySmall),
                kwBox,
                _legendDot(color: kRed),
                const SizedBox(width: 4),
                Text('Expense', style: textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot({required Color color}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MonthLinePoint {
  final DateTime month;
  final double income;
  final double expense;
  final double budget;

  _MonthLinePoint({
    required this.month,
    required this.income,
    required this.expense,
    required this.budget,
  });
}