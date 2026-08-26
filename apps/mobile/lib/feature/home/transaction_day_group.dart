import 'package:mobile/feature/transaction/transaction.dart';

class TransactionDayGroup {
  const TransactionDayGroup({required this.date, required this.transactions});

  final DateTime date;
  final List<Transaction> transactions;
  // 今日总收入
  int get income {
    return transactions
        .where((transaction) => transaction.type == "income")
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  // 今日总支出
  int get expense {
    return transactions
        .where((transaction) => transaction.type == "expense")
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  // 总余额
  int get balance {
    return income - expense;
  }
}

// 转换年月日。
DateTime dateOnly(DateTime date) {
  final local = date.toLocal();

  return DateTime(local.year, local.month, local.day);
}

// 每日数据概览
List<TransactionDayGroup> groupTransactionsByDay(
  List<Transaction> transactions,
) {
  final groups = <DateTime, List<Transaction>>{};
  for (final transaction in transactions) {
    final date = dateOnly(transaction.occurredAt);
    groups.putIfAbsent(date, () => []).add(transaction);
  }
  final entries = groups.entries.toList()
    ..sort((a, b) {
      return b.key.compareTo(a.key);
    });
  return entries.map((entry) {
    return TransactionDayGroup(date: entry.key, transactions: entry.value);
  }).toList();
}

// 将日期格式化为星期*
bool isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

// 格式化为星期 最近两天则显示今日 昨天 今年的显示月份日期 其他显示年月日
String formatGroupDate(DateTime date) {
  final today = dateOnly(DateTime.now());

  final yesterday = today.subtract(const Duration(days: 1));

  final String dateText;

  if (isSameDay(date, today)) {
    dateText = "今日";
  } else if (isSameDay(date, yesterday)) {
    dateText = "昨日";
  } else if (date.year == today.year) {
    dateText = "${date.month}月${date.day}";
  } else {
    dateText = "${date.year}年${date.month}月${date.day}";
  }
  const weekends = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"];
  final weekday = weekends[date.weekday - 1];

  return "$dateText $weekday";
}

// 格式化时间
String formatTransactionTime(DateTime date) {
  final local = date.toLocal();

  final hour = local.hour.toString().padLeft(2, "0");

  final minute = local.minute.toString().padLeft(2, "0");

  return "$hour:$minute";
}
