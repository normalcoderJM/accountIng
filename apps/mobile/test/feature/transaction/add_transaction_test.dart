import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/feature/transaction/add_transaction.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/feature/transaction/transaction.dart';

void main() {
  group('AddTransaction', () {
    testWidgets('金额为空时应该显示错误，并且不发送请求', (tester) async {
      // Arrange：清空测试环境中的 Token
      SharedPreferences.setMockInitialValues({});

      var requestWasSent = false;

      final mockHttpClient = MockClient((request) async {
        // 如果执行这里，说明表单校验没有阻止请求
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

      // 把新增账单页面放进测试环境
      await tester.pumpWidget(
        MaterialApp(home: AddTransaction(transactionApi: transactionApi)),
      );

      // 确认打开的是新增页面
      expect(find.text('新增账单'), findsOneWidget);

      final saveButton = find.widgetWithText(FilledButton, '保存');

      // 确保保存按钮已经滚动到可点击位置
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Act：金额为空，直接点击保存
      await tester.tap(saveButton);

      // 等待错误提示动画出现
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert：金额输入框下面的校验错误
      expect(find.text('请输入金额'), findsOneWidget);

      // Assert：页面底部的 SnackBar 提示
      expect(find.text('请检查表单输入是否正确'), findsOneWidget);

      // 表单不合法，不能调用后端
      expect(requestWasSent, isFalse);

      // 让 SnackBar 动画执行完成，避免遗留定时器
      await tester.pumpAndSettle();

      apiClient.close();
    });

    testWidgets('新增账单成功后应该关闭页面并返回 created', (tester) async {
      // Arrange：模拟已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;

        expect(request.method, 'POST');

        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/transactions',
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        // 页面输入 12.34 元，发送给后端应该是 1234 分
        expect(body['amount'], 1234);
        expect(body['type'], 'income');
        expect(body['category'], '工资');
        expect(body['note'], '');

        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': {
              'id': 10,
              'type': 'income',
              'amount': 1234,
              'category': '工资',
              'note': '',
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

      TransactionChange? returnedChange;

      // 创建一个入口页面，然后通过 Navigator 打开新增账单页面
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
                            );
                          },
                        ),
                      );
                    },
                    child: const Text('打开新增账单'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // 打开新增账单页面
      await tester.tap(find.text('打开新增账单'));
      await tester.pumpAndSettle();

      expect(find.text('新增账单'), findsOneWidget);

      // 当前页面只有金额输入框是 TextFormField
      final amountField = find.byType(TextFormField);

      expect(amountField, findsOneWidget);

      // 输入 12.34 元
      await tester.enterText(amountField, '12.34');

      final saveButton = find.widgetWithText(FilledButton, '保存');

      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Act：点击保存
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Assert：只发送了一次请求
      expect(requestCount, 1);

      // 保存成功后，新增页面应该关闭
      expect(find.text('新增账单'), findsNothing);

      // 页面应该向上一页返回 created
      expect(returnedChange, TransactionChange.created);

      apiClient.close();
    });

    testWidgets('保存失败时应该保留页面并显示错误弹窗', (tester) async {
      // Arrange：模拟用户已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;

        // 模拟后端拒绝创建账单
        return http.Response(
          jsonEncode({'code': 40001, 'message': '账单保存失败，请稍后重试'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      final transactionApi = TransactionApi(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(home: AddTransaction(transactionApi: transactionApi)),
      );

      // 输入合法金额，确保请求能够进入 API 层
      final amountField = find.byType(TextFormField);

      await tester.enterText(amountField, '25.50');

      final saveButton = find.byKey(const Key("save_transaction_button"));

      // ListView 会延迟构建屏幕外组件，因此需要一边滚动一边查找
      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(ListView),
      );

      await tester.pumpAndSettle();

      // Act：点击保存
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Assert：发送了一次请求
      expect(requestCount, 1);

      // 新增页面不能因为保存失败而关闭
      expect(find.text('新增账单'), findsOneWidget);

      // 应该显示正式的错误对话框
      expect(find.text('请求失败'), findsOneWidget);

      // 应该显示后端提供的错误信息
      expect(find.text('账单保存失败，请稍后重试'), findsOneWidget);

      // 弹窗应该提供关闭按钮
      expect(find.text('知道了'), findsOneWidget);

      // 关闭错误弹窗
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      // 弹窗消失
      expect(find.text('请求失败'), findsNothing);

      // 页面仍然保留，用户可以修改后重新保存
      expect(find.text('新增账单'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);

      apiClient.close();
    });

    testWidgets('保存请求进行中时应该阻止重复提交', (tester) async {
      // Arrange：模拟已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      var requestCount = 0;

      // 由测试手动决定请求什么时候返回
      final responseCompleter = Completer<http.Response>();

      final mockHttpClient = MockClient((request) async {
        requestCount++;

        // 请求暂时停在这里
        return responseCompleter.future;
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      final transactionApi = TransactionApi(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(home: AddTransaction(transactionApi: transactionApi)),
      );

      // 输入合法金额
      await tester.enterText(find.byType(TextFormField), '20.00');

      final saveButton = find.byKey(const Key("save_transaction_button"));

      // ListView 会延迟构建屏幕外组件，因此需要一边滚动一边查找
      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(ListView),
      );

      await tester.pumpAndSettle();

      // 先记录按钮所在位置
      final saveButtonPosition = tester.getCenter(saveButton);

      // Act：第一次点击保存
      await tester.tapAt(saveButtonPosition);

      // 只推进有限时间，不能在请求挂起时使用 pumpAndSettle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 请求应该已经发送一次
      expect(requestCount, 1);

      // 应该显示加载动画
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 加载期间按钮必须被禁用
      final loadingButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );

      expect(loadingButton.onPressed, isNull);

      // 模拟用户在相同位置再次点击
      await tester.tapAt(saveButtonPosition);
      await tester.pump();

      // 仍然只能有一个请求
      expect(requestCount, 1);

      // 让暂时挂起的请求返回错误，结束测试
      responseCompleter.complete(
        http.Response(
          jsonEncode({'code': 50001, 'message': '测试请求结束'}),
          500,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await tester.pumpAndSettle();

      // 请求结束后会显示错误弹窗
      expect(find.text('请求失败'), findsOneWidget);
      expect(find.text('测试请求结束'), findsOneWidget);

      // 关闭弹窗
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      // 保存按钮应该恢复
      expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);

      apiClient.close();
    });
  });
}
