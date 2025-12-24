class TransactionModel {
  final int? id;
  final String bankName;
  final double amount;
  final double balance;
  final String type;

  final int? categoryId;
  final String? category;

  final DateTime date;
  final String? notes;

  TransactionModel({
    this.id,
    required this.bankName,
    required this.amount,
    required this.balance,
    required this.type,
    this.categoryId,
    this.category,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bankName': bankName,
      'amount': amount,
      'balance': balance,
      'type': type,
      'categoryId': categoryId,
      'category': category, 
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      bankName: map['bankName'] as String,
      amount: (map['amount'] as num).toDouble(),
      balance: (map['balance'] as num).toDouble(),
      type: (map['type'] as String),
      categoryId: map['categoryId'] as int?,
      category: ( map['category'])?.toString(),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }

  TransactionModel copyWith({
    int? id,
    String? bankName,
    double? amount,
    double? balance,
    String? type,
    int? categoryId,
    String? category,
    DateTime? date,
    String? notes,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      amount: amount ?? this.amount,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }
}
