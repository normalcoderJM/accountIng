import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/token_storage.dart";
import "package:mobile/feature/auth/auth_api.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  test("注册接口应该解析并返回类型化登录会话", () async {
    SharedPreferences.setMockInitialValues({});
    final httpClient = MockClient((request) async {
      expect(request.method, "POST");
      expect(
        request.url.toString(),
        "http://localhost:8080/api/v1/auth/register",
      );
      expect(request.headers.containsKey("Authorization"), isFalse);
      expect(jsonDecode(request.body), {
        "email": "new@example.com",
        "password": "password123",
      });

      return http.Response(
        jsonEncode({
          "code": 0,
          "message": "success",
          "data": {
            "token": "new-token",
            "user": {
              "id": 12,
              "email": "new@example.com",
              "createdAt": "2026-09-14T08:00:00Z",
            },
          },
        }),
        201,
        headers: {"content-type": "application/json; charset=utf-8"},
      );
    });
    final apiClient = ApiClient(
      baseUrl: "http://localhost:8080",
      tokenStorage: TokenStorage(),
      httpClient: httpClient,
    );
    final authApi = AuthApi(apiClient: apiClient);

    final session = await authApi.register(
      email: "new@example.com",
      password: "password123",
    );

    expect(session.token, "new-token");
    expect(session.user.id, 12);
    expect(session.user.email, "new@example.com");
    expect(session.user.createdAt, DateTime.utc(2026, 9, 14, 8));
    apiClient.close();
  });

  test("登录响应缺少用户时应该抛出数据格式异常", () async {
    SharedPreferences.setMockInitialValues({});
    final httpClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          "code": 0,
          "message": "success",
          "data": {"token": "new-token"},
        }),
        200,
        headers: {"content-type": "application/json; charset=utf-8"},
      );
    });
    final apiClient = ApiClient(
      baseUrl: "http://localhost:8080",
      tokenStorage: TokenStorage(),
      httpClient: httpClient,
    );
    final authApi = AuthApi(apiClient: apiClient);

    await expectLater(
      authApi.login(email: "test@example.com", password: "password123"),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          "message",
          "登录数据格式不正确",
        ),
      ),
    );
    apiClient.close();
  });
}
