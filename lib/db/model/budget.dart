class BudgetModel {
  final int? id;
  final int categoryId;
  final double amount;

  BudgetModel({
    this.id,
    required this.categoryId,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'amount': amount,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as int?,
      categoryId: map['categoryId'] as int,
      amount: map['amount'] as double,
    );
  }
}