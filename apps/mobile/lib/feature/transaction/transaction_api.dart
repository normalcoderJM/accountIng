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

  Future<Map<String, dynamic>> create({
    required String token,
    required String type,
    required int amount,
    required String category,
    required String note,
  }) async {
    final uri = Uri.parse("$baseUrl/api/v1/transactions");

    final response = await http.post(
      uri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "type": type,
        "amount": amount,
        "category": category,
        "note": note,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
