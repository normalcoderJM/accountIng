import "package:mobile/core/api_client.dart";

// const baseUrl = "http://localhost:8080";

class AuthApi {
  AuthApi({required this.apiClient});

  final ApiClient apiClient;
  // 注册接口
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) {
    return apiClient.post(
      "/api/v1/auth/register",
      requiredAuth: false,
      body: {"email": email, "password": password},
    );
  }

  // 登录接口
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return apiClient.post(
      "/api/v1/auth/login",
      requiredAuth: false,
      body: {"email": email, "password": password},
    );
  }

  // 校验登录状态接口
  Future<Map<String, dynamic>> me() {
    return apiClient.get("/api/v1/auth/me");
  }
}
