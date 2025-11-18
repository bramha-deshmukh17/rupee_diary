class Bank {
  final int? id;
  final String? name;
  final double? balance;

  const Bank({
    this.id,
    required this.name,
    required this.balance,
  });

  Bank copyWith({
    int? id,
    String? name,
    double? balance,
  }) {
    return Bank(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
    );
  }

  factory Bank.fromMap(Map<String, dynamic> map) {
    return Bank(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      name: map['name'] ?? '',
      balance: map['balance'] is double
          ? map['balance']
          : double.tryParse(map['balance'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
    };
  }

}