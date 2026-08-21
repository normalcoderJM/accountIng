import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/feature/home/transaction_day_group.dart';
import 'package:mobile/feature/transaction/transaction.dart';

void main() {
  group('groupTransactionsByDay', () {
    test('应该按日期分组，并按日期从新到旧排列', () {
      // Arrange：准备测试数据
      final transactions = [
        Transaction(
          id: 1,
          type: 'expense',
          amount: 2000,
          category: '餐饮',
          note: '昨天午餐',
          createdAt: DateTime(2026, 8, 17, 12),
        ),
        Transaction(
          id: 2,
          type: 'income',
          amount: 10000,
          category: '工资',
          note: '今天收入',
          createdAt: DateTime(2026, 8, 18, 9),
        ),
        Transaction(
          id: 3,
          type: 'expense',
          amount: 3500,
          category: '购物',
          note: '今天购物',
          createdAt: DateTime(2026, 8, 18, 15),
        ),
      ];

      // Act：调用真正要测试的方法
      final groups = groupTransactionsByDay(transactions);

      // Assert：检查运行结果
      expect(groups.length, 2);

      // 最新日期应该排在第一个
      expect(groups[0].date, DateTime(2026, 8, 18));
      expect(groups[0].transactions.length, 2);
      expect(groups[0].income, 10000);
      expect(groups[0].expense, 3500);
      expect(groups[0].balance, 6500);

      // 较早日期应该排在第二个
      expect(groups[1].date, DateTime(2026, 8, 17));
      expect(groups[1].transactions.length, 1);
      expect(groups[1].income, 0);
      expect(groups[1].expense, 2000);
      expect(groups[1].balance, -2000);
    });
  });
}
