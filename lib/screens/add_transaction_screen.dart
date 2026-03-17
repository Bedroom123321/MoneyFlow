import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../models/category.dart';

class AddTransactionScreen extends StatefulWidget {
  final Wallet wallet;
  final TransactionModel? transaction; // null → создание, не null → редактирование

  const AddTransactionScreen({
    super.key,
    required this.wallet,
    this.transaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late String _type; // income / expense / transfer
  late DateTime _selectedDate;
  bool _isLoading = false;

  bool get _isEditing => widget.transaction != null;

  List<Wallet> _allWallets = [];
  Wallet? _fromWallet; // источник для transfer
  Wallet? _toWallet;   // получатель для transfer

  List<Category> _incomeCategories = [];
  List<Category> _expenseCategories = [];
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final tx = widget.transaction!;
      _type = tx.type;
      _selectedDate = tx.date;
      _amountController =
          TextEditingController(text: tx.amount.toStringAsFixed(2));
      _noteController = TextEditingController(text: tx.note ?? '');
    } else {
      _type = 'income';
      _selectedDate = DateTime.now();
      _amountController = TextEditingController();
      _noteController = TextEditingController();
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final wallets = await DatabaseHelper.instance.getAllWallets();
    final incomeCats =
    await DatabaseHelper.instance.getAllCategories(type: 'income');
    final expenseCats =
    await DatabaseHelper.instance.getAllCategories(type: 'expense');

    Category? initialCategory;

    if (_isEditing && widget.transaction!.categoryId != null) {
      final allCats = [...incomeCats, ...expenseCats];
      final matches =
      allCats.where((c) => c.id == widget.transaction!.categoryId);
      if (matches.isNotEmpty) {
        initialCategory = matches.first;
      }
    }

    setState(() {
      _allWallets = wallets;

      _fromWallet = wallets.isEmpty
          ? null
          : wallets.firstWhere(
            (w) => w.id == widget.wallet.id,
        orElse: () => wallets.first,
      );

      _toWallet = wallets.length < 2
          ? null
          : wallets.firstWhere(
            (w) => w.id != _fromWallet?.id,
        orElse: () => wallets.first,
      );

      _incomeCategories = incomeCats;
      _expenseCategories = expenseCats;
      _selectedCategory = initialCategory;
    });
  }


  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(
        _amountController.text.replaceAll(',', '.'),
      );

      // === Перевод между кошельками ===
      if (_type == 'transfer' && !_isEditing) {
        if (_allWallets.length < 2) {
          throw Exception('Для перевода нужно минимум два кошелька');
        }
        if (_fromWallet == null || _toWallet == null) {
          throw Exception('Выберите кошельки для перевода');
        }
        if (_fromWallet!.id == _toWallet!.id) {
          throw Exception(
              'Кошелёк-источник и получатель должны отличаться');
        }

        await DatabaseHelper.instance.createTransfer(
          fromWalletId: _fromWallet!.id!,
          toWalletId: _toWallet!.id!,
          amount: amount,
          date: _selectedDate,
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Перевод ${amount.toStringAsFixed(2)} '
                  '${_fromWallet!.currency} выполнен',
            ),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      // === Редактирование существующей операции ===
      if (_isEditing) {
        final oldTx = widget.transaction!;

        final updatedTx = TransactionModel(
          id: oldTx.id,
          walletId: oldTx.walletId,
          type: _type,
          amount: amount,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          categoryId: _selectedCategory?.id,
          createdAt: oldTx.createdAt,
        );

        await DatabaseHelper.instance.updateTransaction(oldTx, updatedTx);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Операция обновлена'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context, true);
      } else {
        // === Новая доходная/расходная операция ===
        final tx = TransactionModel(
          walletId: widget.wallet.id!,
          type: _type,
          amount: amount,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          categoryId: _selectedCategory?.id,
        );

        await DatabaseHelper.instance.createTransaction(tx);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == 'income'
                  ? 'Доход на сумму ${amount.toStringAsFixed(2)} ${widget.wallet.currency} добавлен'
                  : 'Расход на сумму ${amount.toStringAsFixed(2)} ${widget.wallet.currency} добавлен',
            ),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
    _isEditing ? 'Редактировать операцию' : 'Добавить операцию';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_type != 'transfer') _buildWalletInfo(widget.wallet),
              const SizedBox(height: 24),

              _buildTypeToggle(),
              const SizedBox(height: 24),

              _buildAmountField(),
              const SizedBox(height: 20),

              // Выбор категории для доходов/расходов
              if (_type == 'income' || _type == 'expense')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Категория',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Category>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: (_type == 'income'
                          ? _incomeCategories
                          : _expenseCategories)
                          .map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // Выбор кошельков для перевода
              if (_type == 'transfer' && _allWallets.length > 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Wallet>(
                      value: _fromWallet,
                      decoration: const InputDecoration(
                        labelText: 'С какого кошелька',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.arrow_upward),
                      ),
                      items: _allWallets.map((w) {
                        return DropdownMenuItem(
                          value: w,
                          child: Text('${w.name} (${w.currency})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _fromWallet = value;
                          if (_toWallet != null &&
                              _toWallet!.id == _fromWallet!.id) {
                            _toWallet = _allWallets.firstWhere(
                                  (w) => w.id != _fromWallet!.id,
                              orElse: () => _fromWallet!,
                            );
                          }
                        });
                      },
                      validator: (value) {
                        if (_type != 'transfer') return null;
                        if (value == null) return 'Выберите источник';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Wallet>(
                      value: _toWallet?.id == _fromWallet?.id
                          ? null
                          : _toWallet,
                      decoration: const InputDecoration(
                        labelText: 'В какой кошелёк',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.arrow_downward),
                      ),
                      items: _allWallets
                          .where((w) => w.id != _fromWallet?.id)
                          .map((w) {
                        return DropdownMenuItem(
                          value: w,
                          child: Text('${w.name} (${w.currency})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _toWallet = value);
                      },
                      validator: (value) {
                        if (_type != 'transfer') return null;
                        if (value == null) return 'Выберите получателя';
                        if (value.id == _fromWallet?.id) {
                          return 'Кошельки должны отличаться';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Дата',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),
                  child: Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}.'
                        '${_selectedDate.month.toString().padLeft(2, '0')}.'
                        '${_selectedDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Примечание',
                  hintText: 'Например: Зарплата, Продукты, Перевод...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    _isEditing
                        ? 'Сохранить изменения'
                        : 'Сохранить операцию',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletInfo(Wallet wallet) {
    return Card(
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wallet.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Баланс: ${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    final canTransfer = _allWallets.length > 1;

    return ToggleButtons(
      isSelected: [
        _type == 'income',
        _type == 'expense',
        _type == 'transfer',
      ],
      borderRadius: BorderRadius.circular(12),
      selectedColor: Colors.white,
      fillColor: _type == 'income'
          ? Colors.green
          : _type == 'expense'
          ? Colors.red
          : Colors.blue,
      onPressed: (index) {
        setState(() {
          if (index == 0) _type = 'income';
          if (index == 1) _type = 'expense';
          if (index == 2) {
            if (!canTransfer) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                  Text('Для перевода нужно как минимум два кошелька'),
                ),
              );
              return;
            }
            _type = 'transfer';
          }
        });
      },
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text('Доход'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text('Расход'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text('Перевод'),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    final sourceWallet =
    _type == 'income' ? widget.wallet : (_fromWallet ?? widget.wallet);

    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: 'Сумма',
        prefixIcon: const Icon(Icons.attach_money),
        suffixText: sourceWallet.currency,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'^\d*[\.,]?\d{0,2}'),
        ),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Введите сумму';
        }
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed == null) {
          return 'Некорректная сумма';
        }
        if (parsed <= 0) {
          return 'Сумма должна быть больше нуля';
        }
        if ((_type == 'expense' || _type == 'transfer') &&
            parsed > sourceWallet.balance &&
            !_isEditing) {
          return 'Недостаточно средств';
        }
        return null;
      },
    );
  }
}
