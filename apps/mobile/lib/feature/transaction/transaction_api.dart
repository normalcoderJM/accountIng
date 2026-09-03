import "package:mobile/core/api_client.dart";
import "package:mobile/feature/transaction/transaction_summary.dart";
import "package:mobile/feature/transaction/transaction_page.dart";

// 返回当前选中家庭id的函数类型
// transactionApi 不直接依赖页面 也不直接依赖householdSessin 只需要知道怎样获得当前家庭id
typedef HouseholdIdProvider = int? Function();

class TransactionApi {
  TransactionApi({required this.apiClient, required this.householdIdProvider});

  final ApiClient apiClient;
  final HouseholdIdProvider householdIdProvider;

  int _requredHouseholdId() {
    final householdId = householdIdProvider();

    if (householdId == null || householdId <= 0) {
      throw const ApiException("请先选择一个家庭");
    }
    return householdId;
  }

  String _transactionsPath() {
    final householdId = _requredHouseholdId();

    return "/api/v1/households/$householdId/transactions";
  }

  // 连接超时时间
  // static const requestTimeout = Duration(seconds: 10);

  // 获取一页账单 cursor为null表示加载第一页 limit 表示每页最多返回条数
  Future<TransactionPage> listPage({
    String? cursor,
    required DateTime startAt,
    required DateTime endAt,
    int limit = 20,
  }) async {
    final queryParameters = <String, String>{
      "limit": limit.toString(),
      "startAt": startAt.toUtc().toIso8601String(),
      "endAt": endAt.toUtc().toIso8601String(),
    };

    // 第一页不需要传cursor
    if (cursor != null) {
      queryParameters["cursor"] = cursor.toString();
    }
    final path = Uri(
      path: _transactionsPath(),
      queryParameters: queryParameters,
    ).toString();
    final result = await apiClient.get(path);
    final data = result["data"];

    if (data is! Map<String, dynamic>) {
      throw const ApiException("账单数据格式不正确");
    }

    try {
      return TransactionPage.fromJson(data);
    } on FormatException {
      throw const ApiException("账单数据格式不正确");
    }
  }

  // 获取当前用户汇总账单
  Future<TransactionSummary> getSummary({
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final queryParameters = <String, String>{
      "startAt": startAt.toUtc().toIso8601String(),
      "endAt": endAt.toUtc().toIso8601String(),
    };

    final path = Uri(
      path: "${_transactionsPath()}/summary",
      queryParameters: queryParameters,
    ).toString();
    final result = await apiClient.get(path);

    final data = result["data"];

    if (data is! Map<String, dynamic>) {
      throw const ApiException("服务器账单格式不正确");
    }

    try {
      return TransactionSummary.fromJson(data);
    } on FormatException {
      throw const ApiException("服务器账单格式不正确");
    }
  }

  // 创建账单接口
  Future<Map<String, dynamic>> create({
    required String type,
    required int amount,
    required String category,
    required String note,
    required DateTime occurredAt,
  }) {
    return apiClient.post(
      _transactionsPath(),
      body: {
        "type": type,
        "amount": amount,
        "category": category,
        "note": note,
        "occurredAt": occurredAt.toUtc().toIso8601String(),
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
    required DateTime occurredAt,
  }) async {
    return apiClient.put(
      "${_transactionsPath()}/$id",
      body: {
        "type": type,
        "amount": amount,
        "category": category,
        "note": note,
        "occurredAt": occurredAt.toUtc().toIso8601String(),
      },
    );
  }

  // 删除账单
  Future<Map<String, dynamic>> delete({required int id}) async {
    return apiClient.delete("${_transactionsPath()}/$id");
  }
}
