import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/feature/transaction/transaction_page.dart';

void main() {
  group('TransactionPage.fromJson', () {
    test('hasMore 为 true 时必须包含 nextCursor', () {
      final json = <String, dynamic>{'items': <dynamic>[], 'hasMore': true};

      expect(() => TransactionPage.fromJson(json), throwsFormatException);
    });

    test('最后一页允许没有 nextCursor', () {
      final json = <String, dynamic>{'items': <dynamic>[], 'hasMore': false};

      final page = TransactionPage.fromJson(json);

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });
  });
}
