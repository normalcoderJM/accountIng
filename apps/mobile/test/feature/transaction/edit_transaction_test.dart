import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/feature/transaction/add_transaction.dart';
import 'package:mobile/feature/transaction/transaction.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  group('编辑账单页面', () {
    testWidgets('应该显示原账单的数据', (tester) async {
      SharedPreferences.setMockInitialValues({});

      var requestWasSent = false;

      final mockHttpClient = MockClient((request) async {
        requestWasSent = true;

        return http.Response('{}', 500);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      final transactionApi = TransactionApi(apiClient: apiClient);

      // 已经存在的账单
      final transaction = Transaction(
        id: 10,
        type: 'expense',
        amount: 2550,
        category: '餐饮',
        note: '午餐',
        createdAt: DateTime(2026, 8, 18, 12, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AddTransaction(
            transactionApi: transactionApi,
            transaction: transaction,
          ),
        ),
      );

      // 编辑模式的页面标题
      expect(find.text('编辑账单'), findsOneWidget);

      // 编辑模式的保存按钮
      expect(find.widgetWithText(FilledButton, '保存修改'), findsOneWidget);

      // 编辑模式应该显示删除按钮
      expect(find.byIcon(Icons.delete), findsOneWidget);

      // 金额 2550 分应该显示成 25.50 元
      final amountField = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );

      expect(amountField.controller?.text, '25.50');

      // 原账单是支出，支出分段按钮应该被选中
      final typeSelector = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );

      expect(typeSelector.selected, {'expense'});

      // 原来的“餐饮”分类应该保持选中
      final categoryChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '餐饮'),
      );

      expect(categoryChip.selected, isTrue);

      // 原来的备注应该显示出来
      expect(find.text('午餐'), findsOneWidget);

      // 只是打开编辑页面，不能调用后端
      expect(requestWasSent, isFalse);

      apiClient.close();
    });
    testWidgets('修改成功后应该关闭页面并返回 updated', (tester) async {
      // Arrange：模拟已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;

        // 修改账单必须使用 PUT
        expect(request.method, 'PUT');

        // 必须修改 ID 为 10 的账单
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/transactions/10',
        );

        expect(request.headers['Authorization'], 'Bearer valid-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        // 页面输入 36.00 元，后端应该收到 3600 分
        expect(body['amount'], 3600);

        // 其他没有修改的字段应该保留
        expect(body['type'], 'expense');
        expect(body['category'], '餐饮');
        expect(body['note'], '午餐');

        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': {
              'id': 10,
              'type': 'expense',
              'amount': 3600,
              'category': '餐饮',
              'note': '午餐',
              'createdAt': '2026-08-18T12:30:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      final transactionApi = TransactionApi(apiClient: apiClient);

      final transaction = Transaction(
        id: 10,
        type: 'expense',
        amount: 2550,
        category: '餐饮',
        note: '午餐',
        createdAt: DateTime(2026, 8, 18, 12, 30),
      );

      TransactionChange? returnedChange;

      // 先创建入口页面，再打开编辑页面
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      returnedChange = await Navigator.push<TransactionChange>(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return AddTransaction(
                              transactionApi: transactionApi,
                              transaction: transaction,
                            );
                          },
                        ),
                      );
                    },
                    child: const Text('打开编辑页面'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // 打开编辑页面
      await tester.tap(find.text('打开编辑页面'));
      await tester.pumpAndSettle();

      expect(find.text('编辑账单'), findsOneWidget);

      // 原金额是 25.50，修改成 36.00
      await tester.enterText(find.byType(TextFormField), '36.00');

      final saveButton = find.widgetWithText(FilledButton, '保存修改');

      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Act：保存修改
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Assert：只能发送一次请求
      expect(requestCount, 1);

      // 保存成功后编辑页面关闭
      expect(find.text('编辑账单'), findsNothing);

      // 返回值必须是 updated
      expect(returnedChange, TransactionChange.updated);

      apiClient.close();
    });

    testWidgets('取消删除时不应该发送请求', (tester) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      var requestWasSent = false;

      final mockHttpClient = MockClient((request) async {
        requestWasSent = true;

        return http.Response(
          jsonEncode({'code': 0, 'message': 'success'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      final transactionApi = TransactionApi(apiClient: apiClient);

      final transaction = Transaction(
        id: 10,
        type: 'expense',
        amount: 2550,
        category: '餐饮',
        note: '午餐',
        createdAt: DateTime(2026, 8, 18, 12, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AddTransaction(
            transactionApi: transactionApi,
            transaction: transaction,
          ),
        ),
      );

      expect(find.text('编辑账单'), findsOneWidget);

      // Act：点击右上角删除按钮
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      // Assert：显示删除确认弹窗
      expect(find.text('删除账单'), findsOneWidget);
      expect(find.text('确定删除这条账单吗?'), findsOneWidget);

      expect(find.text('取消'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      // 仅仅打开确认弹窗，不能发送请求
      expect(requestWasSent, isFalse);

      // Act：选择取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 确认弹窗应该关闭
      expect(find.text('删除账单'), findsNothing);
      expect(find.text('确定删除这条账单吗?'), findsNothing);

      // 编辑页面仍然存在
      expect(find.text('编辑账单'), findsOneWidget);

      // 取消后仍然不能发送请求
      expect(requestWasSent, isFalse);

      apiClient.close();
    });
  });
}
