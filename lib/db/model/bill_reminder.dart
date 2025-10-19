class BillReminderModel {
  final int? id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String category;
  final String? notes;
  final bool isRecurring;
  final String? recurrenceType;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime updatedAt;

  BillReminderModel({
    this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.category,
    this.notes,
    this.isRecurring = false,
    this.recurrenceType,
    this.isPaid = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'category': category,
      'notes': notes,
      'is_recurring': isRecurring ? 1 : 0,
      'recurrence_type': recurrenceType,
      'is_paid': isPaid ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
      recurrenceType: map['recurrence_type'],
      isPaid: map['is_paid'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
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
    String? recurrenceType,
    bool? isPaid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BillReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
