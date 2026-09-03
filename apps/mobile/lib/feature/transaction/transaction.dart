// 类比前端的interface
enum TransactionChange { created, updated, deleted }

class Transaction {
  const Transaction({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.createdAt,
    required this.occurredAt, //账单日期
  });

  final int id;
  final int householdId; //账单属于哪个家庭
  final int userId; //那个成员记录了这笔账
  final String type;
  final int amount;
  final String category;
  final String note;
  final DateTime createdAt;
  final DateTime occurredAt;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final householdId = json["householdId"];
    final userId = json["userId"];
    final type = json["type"];
    final category = json["category"];
    final amount = json['amount'];
    final createdAt = json['createdAt'];
    final occurredAt = json["occurredAt"];

    if (id is! num ||
        id.toInt() <= 0 ||
        householdId is! num ||
        householdId.toInt() <= 0 ||
        userId is! num ||
        userId.toInt() <= 0 ||
        type is! String ||
        amount is! num ||
        amount.toInt() <= 0 ||
        category is! String ||
        category.trim().isEmpty ||
        createdAt is! String ||
        occurredAt is! String) {
      throw const FormatException("账单数据格式不正确");
    }

    if (parsedCreatedAt == null || parseOccurredAt == null) {
      throw const FormatException("账单时间格式不正确");
    }

    return Transaction(
      id: id.toInt(),
      householdId: householdId.toInt(),
      userId: userId.toInt(),
      type: type,
      amount: amount.toInt(),
      category: category.trim(),
      note: json["note"]?.toString() ?? "",
      createdAt: parsedCreatedAt,
      occurredAt: parsedOccurredAt,
    );
  }
}
