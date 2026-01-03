import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

class SpendingBarChart extends StatefulWidget {
  const SpendingBarChart({super.key});

  @override
  State<SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<SpendingBarChart> {
  final List<_MonthExpense> _data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final rows =
          await DatabaseHelper.instance.transactionsDao
              .getLastFiveMonthsExpense();

      // Map DB rows by monthStart string -> totalExpense
      final byMonth = <String, double>{};
      for (final r in rows) {
        final mStr = r['monthStart'] as String;
        final total = (r['totalExpense'] as num?)?.toDouble() ?? 0.0;
        byMonth[mStr] = total;
      }

      _data.clear();

      final now = DateTime.now();
      // build last 5 months (oldest first)
      for (int i = 4; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final key =
            '${month.year.toString().padLeft(4, '0')}-'
            '${month.month.toString().padLeft(2, '0')}-01';

        final total = byMonth[key] ?? 0.0;
        _data.add(_MonthExpense(month, total));
      }
    } catch (_) {
      if (mounted) {
        showSnack('Failed to load chart data', context, error: true);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_data.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(10.0),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No data for last 5 months')),
        ),
      );
    }

    final maxData = _data
        .map((e) => e.total)
        .fold<double>(0, (p, e) => e > p ? e : p);
    final double chartMaxY = maxData <= 0 ? 1 : maxData * 1.4;

    return Card(
      elevation: 8,
      child: Padding(
        padding: EdgeInsetsGeometry.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Expense',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            khBox,
            SizedBox(
              height: 250,

              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: 0,
                  maxY: chartMaxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => kBlack,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _data.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              DateFormat('MMM').format(_data[idx].month),
                              style: textTheme.bodyMedium,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: chartMaxY / 4,
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
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: kSecondaryColor),
                      left: BorderSide(color: kSecondaryColor),
                    ),
                  ),
                  barGroups: List.generate(_data.length, (i) {
                    final d = _data[i];
                    final isHighlighted = i == _data.length - 1; // latest month
                    return _barGroupData(i, d.total, isHighlighted);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _barGroupData(int x, double y, bool isHighlighted) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isHighlighted ? kPrimaryColor : kPrimaryColor.withAlpha(180),
          width: 22,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}

class _MonthExpense {
  final DateTime month;
  final double total;
  _MonthExpense(this.month, this.total);
}
