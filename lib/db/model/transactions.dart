class TransactionModel {
  final int? id;
  final int bankId;
  final double amount;
  final String type; // credit / debit
  final DateTime date;
  final int? category;
  final String? notes;

  TransactionModel({
    this.id,
    required this.bankId,
    required this.amount,
    required this.type,
    required this.date,
    this.category,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_id': bankId,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'category': category,
      'notes': notes,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      bankId: map['bank_id'],
      amount: map['amount'].toDouble(),
      type: map['type'],
      date: DateTime.parse(map['date']),
      category: map['category'],
      notes: map['notes'],
    );
  }

  TransactionModel copyWith({
    int? id,
    int? bankId,
    double? amount,
    String? type,
    DateTime? date,
    int? category,
    String? notes,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      bankId: bankId ?? this.bankId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }
}
