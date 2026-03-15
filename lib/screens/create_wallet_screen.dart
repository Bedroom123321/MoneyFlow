import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet.dart';
import '../database/database_helper.dart';

class CreateWalletScreen extends StatefulWidget {
  final bool isFirstWallet;

  const CreateWalletScreen({
    super.key,
    this.isFirstWallet = false,
  });

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  String _selectedCurrency = 'BYN';
  bool _isLoading = false;

  final List<String> _currencies = ['BYN', 'USD', 'EUR', 'RUB'];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final wallet = Wallet(
        name: _nameController.text.trim(),
        balance: double.parse(_balanceController.text),
        currency: _selectedCurrency,
      );

      await DatabaseHelper.instance.createWallet(wallet);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Кошелёк "${wallet.name}" создан!'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.isFirstWallet) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstWallet
            ? 'Создайте первый кошелёк'
            : 'Новый кошелёк'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isFirstWallet) ...[
                const Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: Colors.teal,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Добро пожаловать в Money Flow!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Для начала создайте свой первый кошелёк',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
              ],

              // Название кошелька
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название кошелька',
                  hintText: 'Например: Наличные',
                  prefixIcon: Icon(Icons.wallet),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название кошелька';
                  }
                  if (value.trim().length > 30) {
                    return 'Максимум 30 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Начальный баланс
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: 'Начальный баланс',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}'),
                  ),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите начальный баланс';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null) {
                    return 'Некорректная сумма';
                  }
                  if (parsed < 0) {
                    return 'Баланс не может быть отрицательным';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Выбор валюты
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Валюта',
                  prefixIcon: Icon(Icons.currency_exchange),
                  border: OutlineInputBorder(),
                ),
                items: _currencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency,
                    child: Text(currency),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCurrency = value);
                  }
                },
              ),
              const SizedBox(height: 32),

              // Кнопка создания
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveWallet,
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
                          'Создать кошелёк',
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
