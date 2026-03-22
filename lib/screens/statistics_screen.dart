import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/wallet.dart';

enum StatsFilterType { expenses, incomes }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Wallet? _activeWallet;

  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  double _income = 0;
  double _expense = 0;
  List<Map<String, dynamic>> _categorySums = [];
  bool _isLoading = true;

  StatsFilterType _filter = StatsFilterType.expenses;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime get _monthStart =>
      DateTime(_currentMonth.year, _currentMonth.month, 1);

  DateTime get _monthEnd =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 1)
          .subtract(const Duration(seconds: 1));

  String get _monthLabel {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель',
      'Май', 'Июнь', 'Июль', 'Август',
      'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  Color _categoryColor(int? categoryId) {
    const colors = [
      Color(0xFFE53935),
      Color(0xFF8E24AA),
      Color(0xFF1E88E5),
      Color(0xFF00897B),
      Color(0xFFFFB300),
      Color(0xFF43A047),
      Color(0xFFF4511E),
      Color(0xFF6D4C41),
      Color(0xFF546E7A),
      Color(0xFF00ACC1),
    ];
    if (categoryId == null) return Colors.grey;
    return colors[categoryId % colors.length];
  }

  List<Map<String, dynamic>> _calculatePercents(
      List<Map<String, dynamic>> rawData,
      double total,
      ) {
    return rawData.map((item) {
      final amount = (item['total'] as num).toDouble();
      final percent = total > 0 ? (amount / total * 100) : 0.0;
      return {...item, 'percent': percent};
    }).toList();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final wallet = await DatabaseHelper.instance.getActiveWallet();
    if (wallet == null) {
      setState(() {
        _activeWallet = null;
        _isLoading = false;
      });
      return;
    }

    final sums = await DatabaseHelper.instance.getIncomeExpenseSums(
      walletId: wallet.id!,
      from: _monthStart,
      to: _monthEnd,
    );

    final String categoryType;
    final double totalForPercent;

    switch (_filter) {
      case StatsFilterType.incomes:
        categoryType = 'income';
        totalForPercent = sums['income'] ?? 0.0;
        break;
      case StatsFilterType.expenses:
        categoryType = 'expense';
        totalForPercent = sums['expense'] ?? 0.0;
        break;
    }

    final rawCats =
    await DatabaseHelper.instance.getExpensesByCategory(
      walletId: wallet.id!,
      from: _monthStart,
      to: _monthEnd,
      type: categoryType,
    );

    setState(() {
      _activeWallet = wallet;
      _income = sums['income'] ?? 0.0;
      _expense = sums['expense'] ?? 0.0;
      _categorySums = _calculatePercents(rawCats, totalForPercent);
      _isLoading = false;
    });
  }

  void _prevMonth() {
    _currentMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month - 1,
    );
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next =
    DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    _currentMonth = next;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeWallet == null
          ? _buildNoWallet()
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildFilterSelector(),
            const SizedBox(height: 20),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildCategorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWallet() {
    return Center(
      child: Text(
        'Нет активного кошелька',
        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year &&
        _currentMonth.month == now.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _prevMonth,
        ),
        Text(
          _monthLabel,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: isCurrentMonth ? Colors.grey[300] : null,
          ),
          onPressed: isCurrentMonth ? null : _nextMonth,
        ),
      ],
    );
  }

  Widget _buildFilterSelector() {
    return SegmentedButton<StatsFilterType>(
      segments: const [
        ButtonSegment(
          value: StatsFilterType.expenses,
          label: Text('Расходы'),
          icon: Icon(Icons.arrow_upward, size: 16),
        ),
        ButtonSegment(
          value: StatsFilterType.incomes,
          label: Text('Доходы'),
          icon: Icon(Icons.arrow_downward, size: 16),
        ),
      ],
      selected: {_filter},
      onSelectionChanged: (selected) {
        _filter = selected.first;
        _loadData();
      },
      style: ButtonStyle(
        iconColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.teal,
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final net = _income - _expense;
    final netColor = net >= 0 ? Colors.green : Colors.red;
    final currency = _activeWallet?.currency ?? '';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Доходы',
                amount: _income,
                currency: currency,
                color: Colors.green,
                icon: Icons.arrow_downward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Расходы',
                amount: _expense,
                currency: currency,
                color: Colors.red,
                icon: Icons.arrow_upward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Итог за месяц',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${net >= 0 ? '+' : ''}${net.toStringAsFixed(2)} $currency',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: netColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final emptyText = _filter == StatsFilterType.incomes
        ? 'За выбранный период доходов нет'
        : 'За выбранный период расходов нет';

    final sectionTitle = _filter == StatsFilterType.incomes
        ? 'Доходы по категориям'
        : 'Расходы по категориям';

    if (_categorySums.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                emptyText,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryChart(
          items: _categorySums,
          colorOf: _categoryColor,
        ),
        const SizedBox(height: 16),
        Text(
          sectionTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._categorySums.map((item) {
          final name =
              (item['category_name'] as String?) ?? 'Без категории';
          final amount = (item['total'] as num).toDouble();
          final percent = (item['percent'] as num).toDouble();
          final categoryId = item['category_id'] as int?;

          return _CategoryRow(
            name: name,
            amount: amount,
            currency: _activeWallet?.currency ?? '',
            percent: percent,
            color: _categoryColor(categoryId),
          );
        }),
      ],
    );
  }
}

// ── Виджеты ──────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${amount.toStringAsFixed(2)} $currency',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Color Function(int? categoryId) colorOf;

  const _CategoryChart({
    required this.items,
    required this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Структура',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 20,
                child: Row(
                  children: items.map((item) {
                    final percent =
                    (item['percent'] as num).toDouble();
                    final categoryId =
                    item['category_id'] as int?;
                    return Flexible(
                      flex: (percent * 100).round(),
                      child: Container(
                          color: colorOf(categoryId)),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: items.map((item) {
                final name =
                    (item['category_name'] as String?) ??
                        'Без категории';
                final percent =
                (item['percent'] as num).toDouble();
                final categoryId =
                item['category_id'] as int?;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorOf(categoryId),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$name ${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
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

class _CategoryRow extends StatelessWidget {
  final String name;
  final double amount;
  final String currency;
  final double percent;
  final Color color;

  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.currency,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${amount.toStringAsFixed(2)} $currency',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
