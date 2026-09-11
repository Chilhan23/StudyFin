class TransactionItem {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final bool isIncome;

  TransactionItem({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.isIncome,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'isIncome': isIncome ? 1 : 0,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(), 
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      isIncome: (map['isIncome'] as int) == 1,
    );
  }

  TransactionItem copyWith({
    int? id,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    bool? isIncome,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      isIncome: isIncome ?? this.isIncome,
    );
  }
}