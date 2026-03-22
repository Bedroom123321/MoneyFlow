import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('money_flow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        currency TEXT NOT NULL DEFAULT 'BYN',
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wallet_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        category_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');


    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- income / expense
        icon TEXT NOT NULL
      )
    ''');

    await db.insert('categories', {
      'name': 'Зарплата',
      'type': 'income',
      'icon': 'salary',
    });
    await db.insert('categories', {
      'name': 'Подарок',
      'type': 'income',
      'icon': 'gift',
    });
    await db.insert('categories', {
      'name': 'Еда',
      'type': 'expense',
      'icon': 'food',
    });
    await db.insert('categories', {
      'name': 'Транспорт',
      'type': 'expense',
      'icon': 'transport',
    });
    await db.insert('categories', {
      'name': 'Жильё',
      'type': 'expense',
      'icon': 'home',
    });
  }


  Future<int> createWallet(Wallet wallet) async {
    final db = await database;

    final count =
    Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM wallets'));

    final walletMap = wallet.toMap();
    if (count == 0) {
      walletMap['is_active'] = 1;
    }

    return await db.insert('wallets', walletMap);
  }

  Future<List<Wallet>> getAllWallets() async {
    final db = await database;
    final result =
    await db.query('wallets', orderBy: 'created_at DESC');
    return result.map((map) => Wallet.fromMap(map)).toList();
  }

  Future<Wallet?> getActiveWallet() async {
    final db = await database;
    final result = await db.query(
      'wallets',
      where: 'is_active = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Wallet.fromMap(result.first);
  }

  Future<void> setActiveWallet(int walletId) async {
    final db = await database;
    await db.update('wallets', {'is_active': 0});
    await db.update(
      'wallets',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [walletId],
    );
  }

  Future<void> updateWalletBalance(int walletId, double newBalance) async {
    final db = await database;
    await db.update(
      'wallets',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [walletId],
    );
  }

  Future<void> deleteWallet(int walletId) async {
    final db = await database;
    await db.delete('wallets', where: 'id = ?', whereArgs: [walletId]);
  }

  Future<void> updateWallet(Wallet wallet) async {
    final db = await database;
    await db.update(
      'wallets',
      {
        'name': wallet.name,
        'balance': wallet.balance,
        'currency': wallet.currency,
      },
      where: 'id = ?',
      whereArgs: [wallet.id],
    );
  }


  // ===== Операции =====

  Future<int> createTransaction(TransactionModel tx) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      final id = await txn.insert('transactions', tx.toMap());

      final walletResult = await txn.query(
        'wallets',
        where: 'id = ?',
        whereArgs: [tx.walletId],
        limit: 1,
      );
      if (walletResult.isEmpty) return id;

      final currentBalance =
      (walletResult.first['balance'] as num).toDouble();

      double newBalance = currentBalance;
      if (tx.type == 'income') {
        newBalance = currentBalance + tx.amount;
      } else if (tx.type == 'expense') {
        newBalance = currentBalance - tx.amount;
      }

      await txn.update(
        'wallets',
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [tx.walletId],
      );

      return id;
    });
  }

  Future<int> createTransfer({
    required int fromWalletId,
    required int toWalletId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      final fromResult = await txn.query(
        'wallets',
        where: 'id = ?',
        whereArgs: [fromWalletId],
        limit: 1,
      );
      final toResult = await txn.query(
        'wallets',
        where: 'id = ?',
        whereArgs: [toWalletId],
        limit: 1,
      );

      if (fromResult.isEmpty || toResult.isEmpty) {
        throw Exception('Кошелёк не найден');
      }

      final fromBalance =
      (fromResult.first['balance'] as num).toDouble();
      final toBalance =
      (toResult.first['balance'] as num).toDouble();

      if (amount <= 0 || amount > fromBalance) {
        throw Exception('Недостаточно средств для перевода');
      }

      final fromName = fromResult.first['name'] as String;
      final toName = toResult.first['name'] as String;

      final dateIso = date.toIso8601String();
      final createdIso = DateTime.now().toIso8601String();

      final String outNote =
      note?.trim().isNotEmpty == true ? note!.trim() : 'Перевод в "$toName"';
      final String inNote =
      note?.trim().isNotEmpty == true ? note!.trim() : 'Перевод из "$fromName"';

      // Исходящий перевод
      final outId = await txn.insert('transactions', {
        'wallet_id': fromWalletId,
        'type': 'transfer',
        'amount': amount,
        'date': dateIso,
        'note': outNote,
        'created_at': createdIso,
      });

      // Входящий перевод
      await txn.insert('transactions', {
        'wallet_id': toWalletId,
        'type': 'transfer',
        'amount': amount,
        'date': dateIso,
        'note': inNote,
        'created_at': createdIso,
      });

      await txn.update(
        'wallets',
        {'balance': fromBalance - amount},
        where: 'id = ?',
        whereArgs: [fromWalletId],
      );
      await txn.update(
        'wallets',
        {'balance': toBalance + amount},
        where: 'id = ?',
        whereArgs: [toWalletId],
      );

      return outId;
    });
  }


  Future<void> updateTransaction(TransactionModel oldTx, TransactionModel newTx) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Откатываем влияние старой операции на баланс кошелька
      final walletResult = await txn.query(
        'wallets',
        where: 'id = ?',
        whereArgs: [oldTx.walletId],
        limit: 1,
      );
      if (walletResult.isEmpty) return;

      final currentBalance =
      (walletResult.first['balance'] as num).toDouble();

      double balanceAfterRollback = currentBalance;
      if (oldTx.type == 'income') {
        balanceAfterRollback = currentBalance - oldTx.amount;
      } else if (oldTx.type == 'expense') {
        balanceAfterRollback = currentBalance + oldTx.amount;
      }

      // 2. Применяем новую операцию (пока не поддерживаем смену кошелька)
      double finalBalance = balanceAfterRollback;
      if (newTx.type == 'income') {
        finalBalance = balanceAfterRollback + newTx.amount;
      } else if (newTx.type == 'expense') {
        finalBalance = balanceAfterRollback - newTx.amount;
      }

      await txn.update(
        'wallets',
        {'balance': finalBalance},
        where: 'id = ?',
        whereArgs: [newTx.walletId],
      );

      // 3. Обновляем запись в таблице transactions
      await txn.update(
        'transactions',
        newTx.toMap(),
        where: 'id = ?',
        whereArgs: [oldTx.id],
      );
    });
  }


  Future<List<TransactionModel>> getTransactionsForWallet(int walletId) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'wallet_id = ?',
      whereArgs: [walletId],
      orderBy: 'date DESC',
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<void> deleteTransaction(int transactionId) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Находим удаляемую операцию
      final txResult = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (txResult.isEmpty) return;

      final txMap = txResult.first;
      final walletId = txMap['wallet_id'] as int;
      final type = txMap['type'] as String;
      final amount = (txMap['amount'] as num).toDouble();

      // 2. Для обычных операций (income / expense) — как раньше
      if (type == 'income' || type == 'expense') {
        final walletResult = await txn.query(
          'wallets',
          where: 'id = ?',
          whereArgs: [walletId],
          limit: 1,
        );
        if (walletResult.isEmpty) return;

        final currentBalance =
        (walletResult.first['balance'] as num).toDouble();

        double newBalance = currentBalance;
        if (type == 'income') {
          newBalance = currentBalance - amount;
        } else if (type == 'expense') {
          newBalance = currentBalance + amount;
        }

        await txn.update(
          'wallets',
          {'balance': newBalance},
          where: 'id = ?',
          whereArgs: [walletId],
        );

        await txn.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [transactionId],
        );
        return;
      }

      // 3. Особая логика для transfer
      if (type == 'transfer') {
        // Эта запись может быть либо исходящим, либо входящим переводом.
        // Находим вторую часть перевода: ту же сумму и дату, но другой кошелёк.
        final date = txMap['date'] as String;

        final pairResult = await txn.query(
          'transactions',
          where:
          'type = ? AND amount = ? AND date = ? AND id != ?',
          whereArgs: ['transfer', amount, date, transactionId],
        );

        int? otherWalletId;
        int? otherTxId;

        if (pairResult.isNotEmpty) {
          final other = pairResult.first;
          otherWalletId = other['wallet_id'] as int;
          otherTxId = other['id'] as int;
        }

        // Откатываем баланс кошелька, из которого удаляем запись
        final firstWalletResult = await txn.query(
          'wallets',
          where: 'id = ?',
          whereArgs: [walletId],
          limit: 1,
        );
        if (firstWalletResult.isNotEmpty) {
          final currentBalance =
          (firstWalletResult.first['balance'] as num).toDouble();

          // Если это исходящий перевод (по сути вычитали деньги),
          // то при удалении нужно вернуть сумму обратно.
          // Для входящего — наоборот вычесть.
          double newBalance = currentBalance;
          // Проверить, исходящий это или входящий, можно по note
          final note = txMap['note'] as String? ?? '';
          final isOut = note.contains('в "') || note.contains('на "'); // наш текст
          if (isOut) {
            newBalance = currentBalance + amount;
          } else {
            newBalance = currentBalance - amount;
          }

          await txn.update(
            'wallets',
            {'balance': newBalance},
            where: 'id = ?',
            whereArgs: [walletId],
          );
        }

        // Откатываем баланс второго кошелька, если нашли вторую операцию
        if (otherWalletId != null) {
          final secondWalletResult = await txn.query(
            'wallets',
            where: 'id = ?',
            whereArgs: [otherWalletId],
            limit: 1,
          );
          if (secondWalletResult.isNotEmpty) {
            final currentBalance =
            (secondWalletResult.first['balance'] as num).toDouble();

            double newBalance = currentBalance;
            // Для второй записи делаем обратное действие
            final otherNote =
                (pairResult.first['note'] as String?) ?? '';
            final otherIsOut =
                otherNote.contains('в "') || otherNote.contains('на "');
            if (otherIsOut) {
              newBalance = currentBalance + amount;
            } else {
              newBalance = currentBalance - amount;
            }

            await txn.update(
              'wallets',
              {'balance': newBalance},
              where: 'id = ?',
              whereArgs: [otherWalletId],
            );
          }

          // Удаляем вторую запись перевода
          await txn.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [otherTxId],
          );
        }

        // Удаляем первую запись перевода
        await txn.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [transactionId],
        );
      }
    });
  }


  // ===== Категории =====

  Future<List<Category>> getAllCategories({String? type}) async {
    final db = await database;
    List<Map<String, dynamic>> result;
    if (type == null) {
      result = await db.query('categories', orderBy: 'name ASC');
    } else {
      result = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'name ASC',
      );
    }
    return result.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> createCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  Future close() async {
    final db = await database;
    db.close();
    _database = null;
  }

  // ===== Статистика =====

  Future<Map<String, double>> getIncomeExpenseSums({
    required int walletId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;

    final incomeResult = await db.rawQuery(
      '''
    SELECT COALESCE(SUM(amount), 0) AS total
    FROM transactions
    WHERE wallet_id = ? AND type = 'income'
      AND date >= ? AND date <= ?
    ''',
      [walletId, from.toIso8601String(), to.toIso8601String()],
    );

    final expenseResult = await db.rawQuery(
      '''
    SELECT COALESCE(SUM(amount), 0) AS total
    FROM transactions
    WHERE wallet_id = ? AND type = 'expense'
      AND date >= ? AND date <= ?
    ''',
      [walletId, from.toIso8601String(), to.toIso8601String()],
    );

    final income =
        (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final expense =
        (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return {'income': income, 'expense': expense};
  }

  Future<List<Map<String, dynamic>>> getExpensesByCategory({
    required int walletId,
    required DateTime from,
    required DateTime to,
    String type = 'expense', // SCRUM-81: теперь тип передаётся снаружи
  }) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
    SELECT
      c.id        AS category_id,
      c.name      AS category_name,
      COALESCE(SUM(t.amount), 0) AS total
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.wallet_id = ?
      AND t.type = ?
      AND t.date >= ? AND t.date <= ?
    GROUP BY t.category_id
    ORDER BY total DESC
    ''',
      [walletId, type, from.toIso8601String(), to.toIso8601String()],
    );

    return result;
  }


}


