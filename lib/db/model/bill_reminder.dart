class BillReminderModel {
  final int? id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String category;
  final String? notes;
  final bool? isRecurring;
  final bool? isPaid;

  BillReminderModel({
    this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.category,
    this.notes,
    this.isRecurring = false,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'category': category,
      'notes': notes,
      'is_recurring': (isRecurring == true) ? 1 : 0,
      'is_paid': (isPaid == true) ? 1 : 0,
    };
  }

  factory BillReminderModel.fromMap(Map<String, dynamic> map) {
    return BillReminderModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'].toDouble(),
      dueDate: DateTime.parse(map['due_date']),
      category: map['category'],
      notes: map['notes'],
      isRecurring: map['is_recurring'] == 1,
      isPaid: map['is_paid'] == 1,
    );
  }

  BillReminderModel copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    String? category,
    String? notes,
    bool? isRecurring,
    bool? isPaid,
  }) {
    return BillReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
