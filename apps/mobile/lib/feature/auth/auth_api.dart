import "package:mobile/core/api_client.dart";

// 对authUser做一次json对象映射
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  final int id;
  final String email;
  final DateTime createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json["id"];
    final email = json["email"];
    final createdAt = json["createdAt"];

    if (id is! num ||
        id.toInt() <= 0 ||
        email is! String ||
        email.trim().isEmpty ||
        createdAt is! String) {
      throw const ApiException("用户数据格式不正确");
    }

    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) {
      throw const ApiException("用户数据格式不正确");
    }

    return AuthUser(
      id: id.toInt(),
      email: email.trim(),
      createdAt: parsedCreatedAt,
    );
  }
}

// 处理登录的数据存储
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json["token"];
    final user = json["user"];

    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const ApiException("登录数据格式不正确");
    }

    return AuthSession(token: token, user: AuthUser.fromJson(user));
  }
}

//  校验登录注册的合法性 通过login和me接口后才算鉴权成功
abstract interface class AuthGateway {
  Future<AuthSession> register({
    required String email,
    required String password,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<AuthUser> me();
}

// 将登录注册 鉴权方法封装到AuthAPi类里
class AuthApi implements AuthGateway {
  AuthApi({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final result = await apiClient.post(
      "/api/v1/auth/register",
      requiredAuth: false,
      body: {"email": email, "password": password},
    );
    return AuthSession.fromJson(_readData(result, "注册数据格式不正确"));
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final result = await apiClient.post(
      "/api/v1/auth/login",
      requiredAuth: false,
      body: {"email": email, "password": password},
    );
    return AuthSession.fromJson(_readData(result, "登录数据格式不正确"));
  }

  @override
  Future<AuthUser> me() async {
    final result = await apiClient.get("/api/v1/auth/me");
    return AuthUser.fromJson(_readData(result, "用户数据格式不正确"));
  }

  // 校验数据合法性
  Map<String, dynamic> _readData(
    Map<String, dynamic> result,
    String errorMessage,
  ) {
    final data = result["data"];
    if (data is! Map<String, dynamic>) {
      throw ApiException(errorMessage);
    }
    return data;
  }
}
