class ExpenseCategory {
  final String id;
  final String name;
  final bool isUncategorized;
  final String defaultColorHex;
  final int sortOrder;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.isUncategorized,
    required this.defaultColorHex,
    required this.sortOrder,
  });

  ExpenseCategory copyWith({
    String? id,
    String? name,
    bool? isUncategorized,
    String? defaultColorHex,
    int? sortOrder,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      isUncategorized: isUncategorized ?? this.isUncategorized,
      defaultColorHex: defaultColorHex ?? this.defaultColorHex,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_uncategorized': isUncategorized ? 1 : 0,
      'default_color_hex': defaultColorHex,
      'sort_order': sortOrder,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    final rawUncat = map['is_uncategorized'];
    final isUncat = rawUncat == true || rawUncat == 1;
    return ExpenseCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      isUncategorized: isUncat,
      defaultColorHex: map['default_color_hex'] as String? ?? '#FF64748B',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
