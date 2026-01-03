class BudgetModel {
  final int? id;
  final int categoryId;
  final int year;
  final int month;
  final double amount;

  BudgetModel({
    this.id,
    required this.categoryId,
    required this.year,
    required this.month,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'year': year,
      'month': month,
      'amount': amount,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as int?,
      categoryId: map['categoryId'] as int,
      year: map['year'] as int,
      month: map['month'] as int,
      amount: (map['amount'] as num).toDouble(),
    );
  }
}
