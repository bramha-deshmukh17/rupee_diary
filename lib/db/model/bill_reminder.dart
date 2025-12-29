class BillReminderModel {
  final int? id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final int? categoryId;
  final String? notes;
  final bool? isRecurring;
  final bool? isPaid;

  BillReminderModel({
    this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.categoryId,
    this.notes,
    this.isRecurring = false,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'categoryId': categoryId,
      'notes': notes,
      'isRecurring': (isRecurring == true) ? 1 : 0,
      'isPaid': (isPaid == true) ? 1 : 0,
    };
  }

  factory BillReminderModel.fromMap(Map<String, dynamic> map) {
    return BillReminderModel(
      id: map['id'] as int?,
      title: map['title']?.toString() ?? '',
      amount: (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['dueDate'] as String),
      categoryId: map['categoryId'] as int?,
      notes: map['notes']?.toString(),
      isRecurring: map['isRecurring'] == 1,
      isPaid: map['isPaid'] == 1,
    );
  }

  BillReminderModel copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    int? categoryId,
    String? notes,
    bool? isRecurring,
    bool? isPaid,
  }) {
    return BillReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
