class Wallet {
  final int? id;
  final String name;
  final double balance;
  final String currency;
  final bool isActive;
  final DateTime createdAt;

  Wallet({
    this.id,
    required this.name,
    required this.balance,
    this.currency = 'BYN',
    this.isActive = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Конвертация в Map для сохранения в SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'currency': currency,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Создание объекта из Map (из SQLite)
  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'] as int?,
      name: map['name'] as String,
      balance: (map['balance'] as num).toDouble(),
      currency: map['currency'] as String,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Копирование с изменением полей
  Wallet copyWith({
    int? id,
    String? name,
    double? balance,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, balance: $balance, currency: $currency, isActive: $isActive)';
  }
}
