import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

class AddTransactionScreen extends StatefulWidget {
  final Wallet wallet;

  const AddTransactionScreen({super.key, required this.wallet});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'income';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

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

      final tx = TransactionModel(
        walletId: widget.wallet.id!,
        type: _type,
        amount: amount,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
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
    final wallet = widget.wallet;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить операцию'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
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
                        'Текущий баланс: ${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ToggleButtons(
                isSelected: [
                  _type == 'income',
                  _type == 'expense',
                ],
                borderRadius: BorderRadius.circular(12),
                selectedColor: Colors.white,
                fillColor: _type == 'income' ? Colors.green : Colors.red,
                onPressed: (index) {
                  setState(() {
                    _type = index == 0 ? 'income' : 'expense';
                  });
                },
                children: const [
                  Padding(
                    padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('Доход'),
                  ),
                  Padding(
                    padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('Расход'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Сумма',
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: wallet.currency,
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
                  final parsed = double.tryParse(
                      value.replaceAll(',', '.'));
                  if (parsed == null) {
                    return 'Некорректная сумма';
                  }
                  if (parsed <= 0) {
                    return 'Сумма должна быть больше нуля';
                  }
                  if (_type == 'expense' && parsed > wallet.balance) {
                    return 'Недостаточно средств в кошельке';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

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
                  hintText: 'Например: Зарплата, Продукты, Аренда...',
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
                      : const Text(
                    'Сохранить операцию',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
