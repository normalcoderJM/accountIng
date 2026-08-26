class TransactionCategorySummary {
  const TransactionCategorySummary({
    required this.type,
    required this.category,
    required this.amount,
  });

  final String type;
  final String category;
  // 单位仍然是分
  final int amount;

  factory TransactionCategorySummary.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final category = json['category'];
    final amount = json['amount'];

    if (type is! String ||
        category is! String ||
        amount is! num ||
        (type != "income" && type != "expense")) {
      throw const FormatException("账单汇总数据格式不正确");
    }
    return TransactionCategorySummary(
      type: type,
      category: category,
      amount: amount.toInt(),
    );
  }
}

class TransactionSummary {
  const TransactionSummary({
    required this.income,
    required this.expense,
    required this.balance,
    required this.categories,
  });

  static const empty = TransactionSummary(
    income: 0,
    expense: 0,
    balance: 0,
    categories: [],
  );

  final int income;
  final int expense;
  final int balance;
  // 后端基于当前月份全部账单聚合的数据
  final List<TransactionCategorySummary> categories;

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    final income = json['income'];
    final expense = json['expense'];
    final balance = json['balance'];
    final rawCategories = json['categories'];

    if (income is! num ||
        expense is! num ||
        balance is! num ||
        rawCategories is! List) {
      throw const FormatException("分类汇总数据格式不正确");
    }
    final categories = rawCategories
        .map<TransactionCategorySummary>((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException("分类汇总数据格式不正确");
          }
          return TransactionCategorySummary.fromJson(item);
        })
        .toList(growable: false);

    return TransactionSummary(
      income: income.toInt(),
      expense: expense.toInt(),
      balance: balance.toInt(),
      categories: categories,
    );
  }
}
