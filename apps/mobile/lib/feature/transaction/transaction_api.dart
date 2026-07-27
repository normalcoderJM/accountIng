import "dart:convert";

import "package:http/http.dart" as http;

class TransactionApi {
  TransactionApi({required this.baseUrl});

  final String baseUrl;

  Future<Map<String, dynamic>> list(String token) async {
    final uri = Uri.parse("$baseUrl/api/v1/transactions");

    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
