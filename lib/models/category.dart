class Category {
  final int? id;
  final String name;
  final String type; // 'income' или 'expense'
  final String icon; // простая текстовая метка иконки, пока без MaterialIcons

  Category({
    this.id,
    required this.name,
    required this.type,
    this.icon = 'default',
  });

  Category copyWith({
    int? id,
    String? name,
    String? type,
    String? icon,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String? ?? 'default',
    );
  }
}
