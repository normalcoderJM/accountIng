// 类比前端的interface
enum TransactionChange { created, updated, deleted }

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final String type;
  final int amount;
  final String category;
  final String note;
  final DateTime createdAt;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json["id"] as int,
      type: json["type"] as String,
      amount: json["amount"] as int,
      category: json["category"] as String,
      note: json["note"] as String,
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }
}
