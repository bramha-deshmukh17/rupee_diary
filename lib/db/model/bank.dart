class BankModel {
  final int? id;
  final String? name;
  final double? balance;
  final bool? isDefault;

  const BankModel({this.id, this.name, this.balance, this.isDefault});

  BankModel copyWith({int? id, String? name, double? balance, bool? isDefault}) =>
      BankModel(
        id: id ?? this.id,
        name: name ?? this.name,
        balance: balance ?? this.balance,
        isDefault: isDefault ?? this.isDefault,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'balance': balance,
    'isDefault': (isDefault ?? false) ? 1 : 0,
  };

  factory BankModel.fromMap(Map<String, dynamic> m) => BankModel(
    id: m['id'] as int?,
    name: m['name'] as String?,
    balance: (m['balance'] as num?)?.toDouble(),
    isDefault: (m['isDefault'] ?? 0) == 1,
  );
}
