import 'package:expensetracker/core/constants/category_constants.dart';

/// Transaction data entity prepared for SQLite database persistence.
class TransactionModel {
  final dynamic id;
  final String type;
  final double amount;
  final String description;
  final String category;
  final DateTime date;
  final DateTime createdAt;
  final String paymentMethod;
  final String note;
  final String categoryName;

  TransactionModel({
    dynamic id,
    String? type,
    bool? isExpense,
    required this.amount,
    required this.description,
    String? category,
    String? categoryId,
    required this.date,
    DateTime? createdAt,
    String? note,
    String? paymentMethod,
    String? categoryName,
  }) : id = id,
       type = type ?? (isExpense == false ? 'income' : 'expense'),
       category = category ?? categoryId ?? 'other',
       createdAt = createdAt ?? DateTime.now(),
       note = note ?? '',
       paymentMethod = paymentMethod ?? 'other',
       categoryName = categoryName ?? '';

  /// Whether this transaction is an expense
  bool get isExpense => type.toLowerCase() == 'expense';

  /// Whether this transaction is an income
  bool get isIncome => type.toLowerCase() == 'income';

  /// Backwards-compatible category identifier
  String get categoryId => category;

  /// Full category item representation (name, icon, color)
  CategoryItem get categoryItem {
    final item = CategoryCatalog.findById(category);
    return categoryName.isEmpty || categoryName == item.name
        ? item
        : CategoryItem(
            id: item.id,
            name: categoryName,
            icon: item.icon,
            color: item.color,
            backgroundColor: item.backgroundColor,
            isExpense: item.isExpense,
            monthlyBudget: item.monthlyBudget,
          );
  }

  /// Map representation for SQLite integration matching table schema
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type,
      'amount': amount,
      'description': description,
      'category': category,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
    if (id is int) {
      map['id'] = id;
    }
    return map;
  }

  /// Construct from SQLite Map
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      note: map['note'] as String? ?? '',
      paymentMethod: map['payment_method'] as String? ?? 'other',
      categoryName: map['category_name'] as String? ?? '',
    );
  }

  factory TransactionModel.fromFirestore(String id, Map<String, dynamic> map) {
    final dateValue = map['date'];
    final createdValue = map['createdAt'];
    return TransactionModel(
      id: id,
      type: map['type'] as String? ?? 'expense',
      amount: (map['amount'] as num? ?? 0).toDouble(),
      description: map['description'] as String? ?? '',
      category: map['categoryId'] as String? ?? 'other',
      categoryName: map['categoryName'] as String? ?? '',
      date: dateValue is DateTime ? dateValue : dateValue.toDate(),
      createdAt: createdValue is DateTime
          ? createdValue
          : (createdValue?.toDate() ?? DateTime.now()),
      paymentMethod: map['paymentMethod'] as String? ?? 'other',
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'type': type,
    'amount': amount,
    'description': description,
    'categoryId': category,
    if (categoryName.isNotEmpty) 'categoryName': categoryName,
    'date': date,
    'paymentMethod': paymentMethod,
    'note': note,
    'createdAt': createdAt,
    'updatedAt': DateTime.now(),
  };

  TransactionModel copyWith({
    dynamic id,
    String? type,
    double? amount,
    String? description,
    String? category,
    DateTime? date,
    DateTime? createdAt,
    String? note,
    String? paymentMethod,
    String? categoryName,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  @override
  String toString() =>
      'TransactionModel(id: $id, type: $type, amount: $amount, description: $description, category: $category, date: $date, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          amount == other.amount &&
          description == other.description &&
          category == other.category &&
          date == other.date;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      amount.hashCode ^
      description.hashCode ^
      category.hashCode ^
      date.hashCode;
}
