import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../providers/app_providers.dart';
import 'cashbook_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedTab = 'expense';
  int _touchedIndex = -1;
  bool _excludeEvents = false;

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(monthlyCategoryStatsProvider((_selectedDate, _selectedTab, _excludeEvents)));
    final totalsAsync = ref.watch(monthlyTotalsProvider((_selectedDate, _excludeEvents)));
    final dailyAsync = ref.watch(dailyTotalsProvider((_selectedDate, _excludeEvents)));
    final topAsync = ref.watch(topTransactionsProvider((_selectedDate, _excludeEvents)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Sổ quỹ (Cashbook)',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashbookScreen())),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Month Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
                  Text(
                    'Tháng ${_selectedDate.month}/${_selectedDate.year}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                ],
              ),
            ),
          ),

          // Summary Cards
          SliverToBoxAdapter(
            child: totalsAsync.when(
              loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Lỗi: $e')),
              data: (totals) => _buildSummaryCards(totals),
            ),
          ),

          // Tab Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Chi tiêu')),
                  ButtonSegment(value: 'income', label: Text('Thu nhập')),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (val) => setState(() => _selectedTab = val.first),
              ),
            ),
          ),

          // Exclude Events Toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FilterChip(
                label: const Text('Lọc bỏ sự kiện'),
                selected: _excludeEvents,
                onSelected: (val) => setState(() => _excludeEvents = val),
                avatar: Icon(_excludeEvents ? Icons.event_busy : Icons.event, size: 18),
              ),
            ),
          ),

          // Pie Chart
          SliverToBoxAdapter(
            child: statsAsync.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (stats) {
                if (stats.isEmpty) return const SizedBox(height: 80, child: Center(child: Text('Không có dữ liệu')));
                final total = stats.fold(0.0, (sum, item) => sum + item.totalAmount);
                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 0,
                          centerSpaceRadius: 40,
                          sections: _showingSections(stats, total),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Category legend
                    ...stats.asMap().entries.map((e) {
                      final stat = e.value;
                      final pct = (stat.totalAmount / total * 100).toStringAsFixed(1);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 6,
                          backgroundColor: _getColor(e.key),
                        ),
                        title: Text(stat.category.name),
                        trailing: Text('${CurrencyUtils.format(stat.totalAmount)} ($pct%)'),
                      );
                    }),
                  ],
                );
              },
            ),
          ),

          // Daily Bar Chart
          SliverToBoxAdapter(
            child: dailyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (dailyData) {
                if (dailyData.isEmpty) return const SizedBox.shrink();
                return _buildDailyBarChart(dailyData);
              },
            ),
          ),

          // Top Transactions
          SliverToBoxAdapter(
            child: topAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (topTxns) {
                if (topTxns.isEmpty) return const SizedBox.shrink();
                return _buildTopTransactions(topTxns);
              },
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, double> totals) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _summaryCard('Thu nhập', totals['income'] ?? 0, Colors.green),
          const SizedBox(width: 8),
          _summaryCard('Chi tiêu', totals['expense'] ?? 0, Colors.red),
          const SizedBox(width: 8),
          _summaryCard('Cân đối', totals['balance'] ?? 0,
              (totals['balance'] ?? 0) >= 0 ? Colors.blue : Colors.orange),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double amount, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  CurrencyUtils.format(amount),
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyBarChart(List<Map<String, dynamic>> dailyData) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Xu hướng theo ngày', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: dailyData.fold(0.0, (max, d) {
                  final income = (d['income'] as num).toDouble();
                  final expense = (d['expense'] as num).toDouble();
                  final dayMax = income > expense ? income : expense;
                  return dayMax > max ? dayMax : max;
                }) * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = dailyData[groupIndex];
                      final day = d['day'];
                      final label = rodIndex == 0 ? 'Thu' : 'Chi';
                      return BarTooltipItem(
                        'Ngày $day\n$label: ${CurrencyUtils.format(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        if (val.toInt() >= dailyData.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${dailyData[val.toInt()]['day']}', style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: dailyData.asMap().entries.map((e) {
                  final income = (e.value['income'] as num).toDouble();
                  final expense = (e.value['expense'] as num).toDouble();
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(toY: income, color: Colors.green.shade400, width: 6, borderRadius: BorderRadius.circular(2)),
                      BarChartRodData(toY: expense, color: Colors.red.shade400, width: 6, borderRadius: BorderRadius.circular(2)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.green.shade400, 'Thu nhập'),
              const SizedBox(width: 16),
              _legendDot(Colors.red.shade400, 'Chi tiêu'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTopTransactions(List<Transaction> transactions) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top giao dịch', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...transactions.map((t) {
            final isExpense = t.type == 'expense';
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: isExpense ? Colors.red.shade50 : Colors.green.shade50,
                  child: Icon(
                    isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 16,
                    color: isExpense ? Colors.red : Colors.green,
                  ),
                ),
                title: Text(t.note ?? (isExpense ? 'Chi tiêu' : 'Thu nhập'), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${t.date.day}/${t.date.month}/${t.date.year}', style: const TextStyle(fontSize: 11)),
                trailing: Text(
                  '${isExpense ? "-" : "+"}${CurrencyUtils.format(t.amount)}',
                  style: TextStyle(
                    color: isExpense ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<PieChartSectionData> _showingSections(List<CategoryStat> stats, double total) {
    return List.generate(stats.length, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 25.0 : 16.0;
      final radius = isTouched ? 60.0 : 50.0;
      final stat = stats[i];
      final percentage = (stat.totalAmount / total) * 100;

      return PieChartSectionData(
        color: _getColor(i),
        value: stat.totalAmount,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    });
  }

  Color _getColor(int index) {
    const colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.pink, Colors.brown, Colors.indigo, Colors.cyan,
    ];
    return colors[index % colors.length];
  }
}
