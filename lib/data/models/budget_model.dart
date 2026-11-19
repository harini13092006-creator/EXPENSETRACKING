/// Budget data entity representing monthly spending limits.
class BudgetModel {
  final dynamic id;
  final int month;
  final int year;
  final double amount;
  final DateTime createdAt;

  BudgetModel({
    this.id,
    required this.month,
    required this.year,
    required this.amount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Map representation for SQLite integration
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'month': month,
      'year': year,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Construct from SQLite Map
  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as int?,
      month: map['month'] as int,
      year: map['year'] as int,
      amount: (map['amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  factory BudgetModel.fromFirestore(String id, Map<String, dynamic> map) => BudgetModel(
        id: id,
        month: (map['month'] as num).toInt(),
        year: (map['year'] as num).toInt(),
        amount: (map['amount'] as num).toDouble(),
        createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      );

  BudgetModel copyWith({
    int? id,
    int? month,
    int? year,
    double? amount,
    DateTime? createdAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      month: month ?? this.month,
      year: year ?? this.year,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'BudgetModel(id: $id, month: $month, year: $year, amount: $amount, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          month == other.month &&
          year == other.year &&
          amount == other.amount;

  @override
  int get hashCode => id.hashCode ^ month.hashCode ^ year.hashCode ^ amount.hashCode;
}
