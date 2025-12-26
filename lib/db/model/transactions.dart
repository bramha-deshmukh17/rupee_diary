class TransactionModel {
  final int? id;
  final String bankName;
  final double amount;
  final double balance;
  final String type;

  final int? categoryId;
  final String? category;
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;

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
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
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
      'icon_code_point': iconCodePoint,
      'icon_font_family': iconFontFamily,
      'icon_font_package': iconFontPackage,
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
      category: (map['category'])?.toString(),
      iconCodePoint: map['icon_code_point'] as int?,
      iconFontFamily: map['icon_font_family'] as String?,
      iconFontPackage: map['icon_font_package'] as String?,
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
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
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
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }
}
