import 'package:flutter/material.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
import '../database/database_helper.dart';
import 'create_wallet_screen.dart';
import 'wallet_list_screen.dart';
import 'add_transaction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Wallet? _activeWallet;
  bool _isLoading = true;

  double _incomeThisMonth = 0.0;
  double _expenseThisMonth = 0.0;
  List<TransactionModel> _lastTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;

    final active = await db.getActiveWallet();

    if (active == null) {
      setState(() {
        _activeWallet = null;
        _incomeThisMonth = 0.0;
        _expenseThisMonth = 0.0;
        _lastTransactions = [];
        _isLoading = false;
      });
      return;
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final database = await db.database;

    final incomeResult = await database.rawQuery(
      '''
      SELECT SUM(amount) AS total 
      FROM transactions 
      WHERE wallet_id = ? AND type = 'income' AND date >= ?
      ''',
      [active.id, monthStart.toIso8601String()],
    );

    final expenseResult = await database.rawQuery(
      '''
      SELECT SUM(amount) AS total 
      FROM transactions 
      WHERE wallet_id = ? AND type = 'expense' AND date >= ?
      ''',
      [active.id, monthStart.toIso8601String()],
    );

    final incomeTotal =
        (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final expenseTotal =
        (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final lastTxMaps = await database.query(
      'transactions',
      where: 'wallet_id = ?',
      whereArgs: [active.id],
      orderBy: 'date DESC',
      limit: 20,
    );
    final lastTx =
    lastTxMaps.map((e) => TransactionModel.fromMap(e)).toList();

    setState(() {
      _activeWallet = active;
      _incomeThisMonth = incomeTotal;
      _expenseThisMonth = expenseTotal;
      _lastTransactions = lastTx;
      _isLoading = false;
    });
  }

  Future<void> _navigateToCreateWallet() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateWalletScreen()),
    );
    if (result == true) _loadData();
  }

  Future<void> _navigateToWalletList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletListScreen()),
    );
    _loadData();
  }

  Future<void> _navigateToAddTransaction() async {
    if (_activeWallet == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(wallet: _activeWallet!),
      ),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Flow'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Мои кошельки',
            onPressed: _navigateToWalletList,
          ),
        ],
      ),
      body: _activeWallet == null
          ? _buildEmptyState()
          : _buildDashboard(),
      floatingActionButton: _activeWallet != null
          ? FloatingActionButton(
        onPressed: _navigateToAddTransaction,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wallet, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'У вас пока нет кошельков',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCreateWallet,
            icon: const Icon(Icons.add),
            label: const Text('Создать кошелёк'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final wallet = _activeWallet!;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.teal,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          wallet.currency,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Текущий баланс',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.arrow_downward, color: Colors.green),
                        const SizedBox(height: 8),
                        const Text('Доходы',
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          _incomeThisMonth.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.arrow_upward, color: Colors.red),
                        const SizedBox(height: 8),
                        const Text('Расходы',
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          _expenseThisMonth.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Последние операции',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_lastTransactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Операций пока нет',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._lastTransactions.map(_buildTransactionTile).toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx) {
    final isIncome = tx.type == 'income';
    final sign = isIncome ? '+' : '-';
    final color = isIncome ? Colors.green : Colors.red;

    final date = tx.date;
    final dateString =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';

    return InkWell(
      onLongPress: () => _showDeleteTransactionDialog(tx),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(
          tx.note?.isNotEmpty == true
              ? tx.note!
              : (isIncome ? 'Доход' : 'Расход'),
        ),
        subtitle: Text(dateString),
        trailing: Text(
          '$sign${tx.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  void _showDeleteTransactionDialog(TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Удалить операцию'),
                  onTap: () async {
                    Navigator.pop(context);

                    final confirm = await showDialog<bool>(
                      context: this.context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Удалить операцию?'),
                          content: const Text(
                            'Операция будет удалена, а баланс кошелька '
                                'будет пересчитан с учётом её отмены.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text(
                                'Удалить',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm == true) {
                      await DatabaseHelper.instance
                          .deleteTransaction(tx.id!);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Операция удалена'),
                          ),
                        );
                        _loadData();
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
