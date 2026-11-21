class Expense {
  final String id;
  final String userId;
  final double amount;
  final String categoryId;
  final int timestamp;
  final String dateStr;
  final bool isRestDay;
  final String note;
  final int createdAt;
  final int updatedAt;

  const Expense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.categoryId,
    required this.timestamp,
    required this.dateStr,
    required this.isRestDay,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  Expense copyWith({
    String? id,
    String? userId,
    double? amount,
    String? categoryId,
    int? timestamp,
    String? dateStr,
    bool? isRestDay,
    String? note,
    int? createdAt,
    int? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      timestamp: timestamp ?? this.timestamp,
      dateStr: dateStr ?? this.dateStr,
      isRestDay: isRestDay ?? this.isRestDay,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'category_id': categoryId,
      'timestamp': timestamp,
      'date_str': dateStr,
      'is_rest_day': isRestDay ? 1 : 0,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    final rawRest = map['is_rest_day'];
    return Expense(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as String,
      timestamp: (map['timestamp'] as num).toInt(),
      dateStr: map['date_str'] as String,
      isRestDay: rawRest == true || rawRest == 1,
      note: (map['note'] as String?) ?? '',
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (map['updated_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserDayOverride {
  final String userId;
  final String dateStr;
  final bool isRestDay;

  const UserDayOverride({
    required this.userId,
    required this.dateStr,
    required this.isRestDay,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'date_str': dateStr,
      'is_rest_day': isRestDay ? 1 : 0,
    };
  }

  factory UserDayOverride.fromMap(Map<String, dynamic> map) {
    final rawRest = map['is_rest_day'];
    return UserDayOverride(
      userId: map['user_id'] as String,
      dateStr: map['date_str'] as String,
      isRestDay: rawRest == true || rawRest == 1,
    );
  }
}
