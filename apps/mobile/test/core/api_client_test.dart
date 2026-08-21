import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ApiClient', () {
    test('需要登录的请求应该自动携带 Token', () async {
      // Arrange：模拟本地已经保存了登录 Token
      SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});

      // 模拟后端服务器
      final mockHttpClient = MockClient((request) async {
        // 检查 ApiClient 发送的请求
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/transactions',
        );
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.headers['Accept'], 'application/json');

        // 模拟后端返回成功结果
        return http.Response(
          jsonEncode({'code': 0, 'message': 'success', 'data': []}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      // Act：调用需要登录的接口
      final result = await apiClient.get('/api/v1/transactions');

      // Assert：检查解析结果
      expect(result['code'], 0);
      expect(result['message'], 'success');
      expect(result['data'], isEmpty);

      apiClient.close();
    });
    test('没有 Token 时应该抛出 UnauthorizedException，并且不发送请求', () async {
      // Arrange：模拟本地没有保存 Token
      SharedPreferences.setMockInitialValues({});

      var requestWasSent = false;

      final mockHttpClient = MockClient((request) async {
        // 如果执行到这里，说明 ApiClient 错误地发送了请求
        requestWasSent = true;

        return http.Response(
          jsonEncode({'code': 0, 'message': 'success'}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      // Act + Assert：调用需要登录的接口
      await expectLater(
        apiClient.get('/api/v1/transactions'),
        throwsA(isA<UnauthorizedException>()),
      );

      // 因为本地没有 Token，所以不能真正发送 HTTP 请求
      expect(requestWasSent, isFalse);

      apiClient.close();
    });

    test('后端返回 401 时应该清除过期 Token', () async {
      // Arrange：模拟本地保存了一个已经过期的 Token
      SharedPreferences.setMockInitialValues({'auth_token': 'expired-token'});

      final tokenStorage = TokenStorage();

      final mockHttpClient = MockClient((request) async {
        // 请求仍然应该携带本地保存的 Token
        expect(request.headers['Authorization'], 'Bearer expired-token');

        // 模拟后端发现 Token 已经过期
        return http.Response(
          jsonEncode({'code': 40101, 'message': '登录状态已失效'}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        httpClient: mockHttpClient,
      );

      // Act + Assert：应该抛出统一的登录失效异常
      await expectLater(
        apiClient.get('/api/v1/transactions'),
        throwsA(isA<UnauthorizedException>()),
      );

      // 过期 Token 应该已经从本地删除
      final savedToken = await tokenStorage.readToken();

      expect(savedToken, isNull);

      apiClient.close();
    });

    test('登录接口不需要 Token，并且应该正确发送 JSON', () async {
      // Arrange：模拟本地没有 Token
      SharedPreferences.setMockInitialValues({});

      final mockHttpClient = MockClient((request) async {
        // 登录接口使用 POST
        expect(request.method, 'POST');

        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/auth/login',
        );

        // 登录时还没有 Token，不应该存在 Authorization
        expect(request.headers.containsKey('Authorization'), isFalse);

        // 发送 JSON 时应该自动添加 Content-Type
        expect(request.headers['Content-Type'], 'application/json');

        // 检查发送给后端的 JSON
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        expect(requestBody['email'], 'test@example.com');
        expect(requestBody['password'], '123456');

        // 模拟登录成功
        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': {'token': 'new-token'},
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

      // Act：requiredAuth 设置为 false
      final result = await apiClient.post(
        '/api/v1/auth/login',
        requiredAuth: false,
        body: {'email': 'test@example.com', 'password': '123456'},
      );

      // Assert：检查登录响应
      final data = result['data'] as Map<String, dynamic>;

      expect(data['token'], 'new-token');

      apiClient.close();
    });

    test('后端返回业务错误时应该抛出包含错误信息的 ApiException', () async {
      // Arrange：创建账单是登录接口，需要本地 Token
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      final mockHttpClient = MockClient((request) async {
        expect(request.method, 'POST');

        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/transactions',
        );

        expect(request.headers['Authorization'], 'Bearer valid-token');

        // 模拟后端参数校验失败
        return http.Response(
          jsonEncode({'code': 40001, 'message': '金额必须大于 0'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      // Act + Assert
      await expectLater(
        apiClient.post(
          '/api/v1/transactions',
          body: {'type': 'expense', 'amount': 0, 'category': '餐饮', 'note': ''},
        ),
        throwsA(
          isA<ApiException>().having(
            (exception) => exception.message,
            'message',
            '金额必须大于 0',
          ),
        ),
      );

      apiClient.close();
    });

    test('服务器返回非 JSON 内容时应该抛出数据格式异常', () async {
      // Arrange：模拟已经登录
      SharedPreferences.setMockInitialValues({'auth_token': 'valid-token'});

      final mockHttpClient = MockClient((request) async {
        // 模拟服务器内部错误，返回的不是 JSON
        return http.Response(
          '<html>Internal Server Error</html>',
          500,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: TokenStorage(),
        httpClient: mockHttpClient,
      );

      // Act + Assert
      await expectLater(
        apiClient.get('/api/v1/transactions'),
        throwsA(
          isA<ApiException>().having(
            (exception) => exception.message,
            'message',
            '服务器返回的数据格式不正确',
          ),
        ),
      );

      apiClient.close();
    });
  });
}
