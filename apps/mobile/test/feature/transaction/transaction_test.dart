import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/feature/transaction/transaction.dart';

void main() {
  group('Transaction.fromJson', () {
    test('应该把后端返回的 JSON 转换成 Transaction', () {
      // Arrange：模拟后端返回的数据
      final json = <String, dynamic>{
        'id': 10,
        'type': 'expense',
        'amount': 2500,
        'category': '餐饮',
        'note': '午餐',
        'occurredAt': '2026-08-17T18:20:00Z',
        'createdAt': '2026-08-18T12:30:00Z',
      };

      // Act：执行 JSON 转换
      final transaction = Transaction.fromJson(json);

      // Assert：检查每个字段
      expect(transaction.id, 10);
      expect(transaction.type, 'expense');
      expect(transaction.amount, 2500);
      expect(transaction.category, '餐饮');
      expect(transaction.note, '午餐');
      expect(transaction.occurredAt, DateTime.utc(2026, 8, 17, 18, 20));
      expect(transaction.createdAt, DateTime.utc(2026, 8, 18, 12, 30));
    });
  });
}
