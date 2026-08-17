import "package:mobile/core/api_client.dart";

class TransactionApi {
  TransactionApi({required this.apiClient});

  final ApiClient apiClient;
  // 连接超时时间
  static const requestTimeout = Duration(seconds: 10);
  // 账单列表接口
  Future<Map<String, dynamic>> list() {
    return apiClient.get("/api/v1/transactions");
  }

  // 创建账单接口
  Future<Map<String, dynamic>> create({
    required String type,
    required int amount,
    required String category,
    required String note,
  }) {
    return apiClient.post(
      "/api/v1/transactions",
      body: {
        "type": type,
        "amount": amount,
        "category": category,
        "note": note,
      },
    );
  }

  // 更新账单接口
  Future<Map<String, dynamic>> update({
    required int id,
    required String type,
    required String category,
    required String note,
    required int amount,
  }) async {
    return apiClient.put(
      "/api/v1/transactions/$id",
      body: {
        "type": type,
        "amount": amount,
        "category": category,
        "note": note,
      },
    );
  }

  // 删除账单
  Future<Map<String, dynamic>> delete({required int id}) async {
    return apiClient.delete("/api/v1/transactions/$id");
  }
}
