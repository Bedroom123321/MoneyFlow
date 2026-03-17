class TransactionModel {
  final int? id;
  final int walletId;
  final String type; // 'income', 'expense', 'transfer'
  final double amount;
  final DateTime date;
  final String? note;
  final int? categoryId;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
    this.categoryId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wallet_id': walletId,
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'category_id': categoryId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      walletId: map['wallet_id'] as int,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      categoryId: map['category_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  String toString() {
    return 'Transaction(id: $id, walletId: $walletId, type: $type, '
        'amount: $amount, categoryId: $categoryId)';
  }
}

