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
    required this.occurredAt, //账单日期
  });

  final int id;
  final String type;
  final int amount;
  final String category;
  final String note;
  final DateTime createdAt;
  final DateTime occurredAt;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final amount = json['amount'];
    final createdAt = json['createdAt'];
    final occurredAt = json["occurredAt"];

    if (id is! num ||
        amount is! num ||
        json["type"] is! String ||
        json["category"] is! String ||
        createdAt is! String ||
        occurredAt is! String) {
      throw const FormatException("账单数据格式不正确");
    }
    return Transaction(
      id: id.toInt(),
      type: json["type"] as String,
      amount: amount.toInt(),
      category: json["category"] as String,
      note: json["note"]?.toString() ?? "",
      createdAt: DateTime.parse(json["createdAt"]),
      occurredAt: DateTime.parse(json["occurredAt"]),
    );
  }
}
