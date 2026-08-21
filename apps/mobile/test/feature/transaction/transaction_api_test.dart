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

    test('list 应该发送账单列表请求并返回数据', () async {
      // Arrange：模拟用户已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      final mockHttpClient = MockClient((request) async {
        // 列表接口应该使用 GET
        expect(request.method, 'GET');

        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/transactions',
        );

        expect(request.headers['Authorization'], 'Bearer valid-token');

        // GET 请求不应该携带请求体
        expect(request.body, isEmpty);

        // 模拟后端返回账单列表
        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': [
              {
                'id': 2,
                'type': 'income',
                'amount': 10000,
                'category': '工资',
                'note': '八月工资',
                'createdAt': '2026-08-18T09:00:00Z',
              },
              {
                'id': 1,
                'type': 'expense',
                'amount': 2500,
                'category': '餐饮',
                'note': '午餐',
                'createdAt': '2026-08-17T12:30:00Z',
              },
            ],
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

      // Act：获取账单列表
      final result = await transactionApi.list();

      // Assert：检查列表数据
      final data = result['data'] as List<dynamic>;

      expect(data.length, 2);

      final first = data[0] as Map<String, dynamic>;

      expect(first['id'], 2);
      expect(first['type'], 'income');
      expect(first['amount'], 10000);
      expect(first['category'], '工资');

      final second = data[1] as Map<String, dynamic>;

      expect(second['id'], 1);
      expect(second['type'], 'expense');
      expect(second['amount'], 2500);

      apiClient.close();
    });
  });
}
