import "package:mobile/feature/transaction/transaction.dart";

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  // 当前页账单
  final List<Transaction> items;
  // 后端游标包含 occurredAt 和 id，所以不能再使用 int
  final String? nextCursor;

  final bool hasMore;

  factory TransactionPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException("items 不是数组");
    }
    final items = rawItems.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException("账单数据格式不正确");
      }
      return Transaction.fromJson(item);
    }).toList();

    final rawNextCursor = json["nextCursor"];
    final rawHasMore = json['hasMore'];

    if (rawNextCursor != null && rawNextCursor is! String) {
      throw const FormatException("nextCursor 格式不正确");
    }
    if (rawHasMore is! bool) {
      throw const FormatException("hasMore 格式不正确");
    }

    if (rawHasMore && rawNextCursor == null) {
      throw const FormatException("hasMore 为 true 时必须返回 nextCursor");
    }

    return TransactionPage(
      items: items,
      nextCursor: rawNextCursor as String?,
      hasMore: rawHasMore,
    );
  }
}
