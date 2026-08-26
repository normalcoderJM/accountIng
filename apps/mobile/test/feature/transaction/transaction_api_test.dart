import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TransactionApi', () {
    test('create 应该发送正确的创建账单请求', () async {
      final occurredAt = DateTime.utc(2026, 8, 18, 12, 30);

      // Arrange：模拟用户已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      final mockHttpClient = MockClient((request) async {
        // 检查请求方式和地址
        expect(request.method, 'POST');

        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/transactions',
        );

        // Token 应该由 ApiClient 自动添加
        expect(request.headers['Authorization'], 'Bearer valid-token');

        // 解析发送给后端的 JSON
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['type'], 'expense');
        expect(body['amount'], 2500);
        expect(body['category'], '餐饮');
        expect(body['note'], '午餐');
        expect(body['occurredAt'], '2026-08-18T12:30:00.000Z');

        // 模拟后端创建成功
        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': {
              'id': 10,
              'type': 'expense',
              'amount': 2500,
              'category': '餐饮',
              'note': '午餐',
              'occurredAt': '2026-08-18T12:30:00Z',
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

      // Act：调用创建账单方法
      final result = await transactionApi.create(
        type: 'expense',
        amount: 2500,
        category: '餐饮',
        note: '午餐',
        occurredAt: occurredAt,
      );

      // Assert：检查返回数据
      final data = result['data'] as Map<String, dynamic>;

      expect(data['id'], 10);
      expect(data['type'], 'expense');
      expect(data['amount'], 2500);
      expect(data['category'], '餐饮');

      apiClient.close();
    });

    test('update 应该发送正确的修改账单请求', () async {
      final occurredAt = DateTime.utc(2026, 8, 17, 18, 20);
      // Arrange：模拟用户已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      final mockHttpClient = MockClient((request) async {
        // 修改接口应该使用 PUT
        expect(request.method, 'PUT');

        // ID 应该放在请求路径中
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/transactions/10',
        );

        expect(request.headers['Authorization'], 'Bearer valid-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['type'], 'expense');
        expect(body['amount'], 3600);
        expect(body['category'], '购物');
        expect(body['note'], '修改后的备注');
        expect(body['occurredAt'], '2026-08-17T18:20:00.000Z');
        // 模拟后端返回修改后的账单
        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': {
              'id': 10,
              'type': 'expense',
              'amount': 3600,
              'category': '购物',
              'note': '修改后的备注',
              'occurredAt': '2026-08-17T18:20:00Z',
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

      // Act：修改 ID 为 10 的账单
      final result = await transactionApi.update(
        id: 10,
        type: 'expense',
        amount: 3600,
        category: '购物',
        occurredAt: occurredAt,
        note: '修改后的备注',
      );

      // Assert：检查后端返回的新数据
      final data = result['data'] as Map<String, dynamic>;

      expect(data['id'], 10);
      expect(data['amount'], 3600);
      expect(data['category'], '购物');
      expect(data['note'], '修改后的备注');

      apiClient.close();
    });

    test('delete 应该发送正确的删除账单请求', () async {
      // Arrange：模拟用户已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      final mockHttpClient = MockClient((request) async {
        // 删除接口应该使用 DELETE
        expect(request.method, 'DELETE');

        // 删除的账单 ID 应该放在 URL 中
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/transactions/10',
        );

        expect(request.headers['Authorization'], 'Bearer valid-token');

        // DELETE 请求不应该发送 JSON 请求体
        expect(request.body, isEmpty);

        // 模拟后端删除成功
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

      // Act：删除 ID 为 10 的账单
      final result = await transactionApi.delete(id: 10);

      // Assert：检查删除结果
      expect(result['code'], 0);
      expect(result['message'], 'success');

      apiClient.close();
    });

    test('listPage 应该发送分页参数并解析分页账单', () async {
      final startAt = DateTime.utc(2026, 8, 1);
      final endAt = DateTime.utc(2026, 9, 1);
      const cursor = '2026-08-18T09:00:00Z_10';
      // Arrange：模拟用户已经登录。
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      final mockHttpClient = MockClient((request) async {
        expect(request.method, 'GET');

        // 分别验证 path 和 queryParameters，
        // 不依赖 URL 查询参数的排列顺序。
        expect(request.url.path, '/api/v1/transactions');

        expect(request.url.queryParameters['cursor'], cursor);
        expect(request.url.queryParameters['limit'], '2');

        expect(
          request.url.queryParameters['startAt'],
          '2026-08-01T00:00:00.000Z',
        );

        expect(
          request.url.queryParameters['endAt'],
          '2026-09-01T00:00:00.000Z',
        );

        expect(request.headers['Authorization'], 'Bearer valid-token');

        expect(request.body, isEmpty);

        // 模拟后端分页响应。
        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': {
              'items': [
                {
                  'id': 9,
                  'type': 'income',
                  'amount': 10000,
                  'category': '工资',
                  'note': '八月工资',
                  'occurredAt': '2026-08-18T09:00:00Z',
                  'createdAt': '2026-08-18T09:00:00Z',
                },
                {
                  'id': 8,
                  'type': 'expense',
                  'amount': 2500,
                  'category': '餐饮',

                  // 同时验证后端 note 为 null 时不会解析崩溃。
                  'note': null,
                  'occurredAt': '2026-08-18T09:00:00Z',
                  'createdAt': '2026-08-17T12:30:00Z',
                },
              ],
              'nextCursor': '2026-08-17T12:30:00Z_8',
              'hasMore': true,
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

      // Act：请求 ID 小于 10 的下一页，每页 2 条。
      final page = await transactionApi.listPage(
        cursor: cursor,
        limit: 2,
        startAt: startAt,
        endAt: endAt,
      );

      // Assert：检查分页状态。
      expect(page.items.length, 2);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, '2026-08-17T12:30:00Z_8');
      // 检查第一页账单模型。
      expect(page.items[0].id, 9);
      expect(page.items[0].type, 'income');
      expect(page.items[0].amount, 10000);
      expect(page.items[0].category, '工资');

      // note 为 null 时应该转换为空字符串。
      expect(page.items[1].id, 8);
      expect(page.items[1].type, 'expense');
      expect(page.items[1].note, '');

      apiClient.close();
    });

    test('getSummary 应该解析全部账单汇总', () async {
      final startAt = DateTime.utc(2026, 8, 1);
      final endAt = DateTime.utc(2026, 9, 1);
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      final mockHttpClient = MockClient((request) async {
        expect(request.method, 'GET');

        expect(request.url.path, '/api/v1/transactions/summary');
        expect(
          request.url.queryParameters['startAt'],
          '2026-08-01T00:00:00.000Z',
        );

        expect(
          request.url.queryParameters['endAt'],
          '2026-09-01T00:00:00.000Z',
        );

        expect(request.headers['Authorization'], 'Bearer valid-token');

        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': {'income': 100000, 'expense': 35000, 'balance': 65000},
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

      final summary = await transactionApi.getSummary(
        startAt: startAt,
        endAt: endAt,
      );

      expect(summary.income, 100000);
      expect(summary.expense, 35000);
      expect(summary.balance, 65000);

      apiClient.close();
    });
  });
}
