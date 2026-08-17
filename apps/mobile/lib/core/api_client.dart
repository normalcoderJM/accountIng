import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:mobile/core/token_storage.dart";

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = "登录状态已失效,请重新登录"])
    : super(message);
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStorage,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStorage tokenStorage;
  final http.Client httpClient;
  static const requestTimeout = Duration(seconds: 10);
  // get方法
  Future<Map<String, dynamic>> get(String path, {bool requiredAuth = true}) {
    return request(method: "GET", path: path, requiredAuth: requiredAuth);
  }

  // post方法
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiredAuth = true,
  }) {
    return request(
      path: path,
      method: "POST",
      body: body,
      requiredAuth: requiredAuth,
    );
  }

  // put方法
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool requiredAuth = true,
  }) {
    return request(
      method: "PUT",
      path: path,
      body: body,
      requiredAuth: requiredAuth,
    );
  }

  // delete方法
  Future<Map<String, dynamic>> delete(String path, {bool requiredAuth = true}) {
    return request(method: "DELETE", path: path, requiredAuth: requiredAuth);
  }

  Future<Map<String, dynamic>> request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool requiredAuth = true,
  }) async {
    final uri = Uri.parse("$baseUrl$path");

    final headers = <String, String>{"Accept": "application/json"};

    if (body != null) {
      headers["Content-Type"] = "application/json";
    }
    // 只有登录需要的接口才需要读取token
    if (requiredAuth) {
      final token = await tokenStorage.readToken();

      if (token == null || token.isEmpty) {
        throw const UnauthorizedException();
      }
      headers["Authorization"] = "Bearer $token";
    }

    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    late final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await httpClient.send(request).timeout(requestTimeout);
    } on TimeoutException {
      throw const ApiException("请求超时,请检查网络或服务器状态");
    } on http.ClientException {
      throw const ApiException("无法连接服务器");
    }
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(requestTimeout);
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException("服务器返回的数据格式不正确");
    }
    // 检验键值对格式
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException("服务器返回的数据格式不正确");
    }

    final result = decoded;
    final code = result["code"];
    final message = result["message"]?.toString() ?? "服务器处理失败";
    if (requiredAuth && response.statusCode == 401) {
      await tokenStorage.clearToken();
      throw const UnauthorizedException();
    }

    final httpSuccess = response.statusCode >= 200 && response.statusCode < 300;
    if (!httpSuccess || code != 0) {
      throw ApiException(message);
    }
    return result;
  }

  void close() {
    httpClient.close();
  }
}
