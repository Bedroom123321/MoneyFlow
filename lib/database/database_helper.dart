import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';

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
        created_at TEXT NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE CASCADE
      )
    ''');
  }

  // ===== Кошельки =====

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
    });
  }

  Future close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
