import "dart:convert";

import "package:http/http.dart" as http;

const baseUrl = "http://localhost:8080";

class AuthApi {
  AuthApi({required this.baseUrl});

  final String baseUrl;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": password}),
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": password}),
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
