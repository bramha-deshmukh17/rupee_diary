class TransactionModel {
  final int? id;
  final String bankName;
  final double amount;
  final double balance;
  final String type; // credit / debit
  final String category;
  final DateTime date;
  final String? notes;

  TransactionModel({
    this.id,
    required this.bankName,
    required this.amount,
    required this.balance,
    required this.type,
    required this.category,
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
      'category': category,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      bankName: map['bankName'],
      amount: map['amount'].toDouble(),
      balance: map['balance'].toDouble(),
      type: map['type'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      notes: map['notes'],
    );
  }

  TransactionModel copyWith({
    int? id,
    String? bankName,
    double? amount,
    double? balance,
    String? type,
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
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }
}
