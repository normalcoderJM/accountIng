import "package:mobile/core/api_client.dart";
import "package:mobile/feature/household/household.dart";

class HouseholdApi {
  const HouseholdApi({required this.apiClient});

  final ApiClient apiClient;
  // 获取当前登录用户加入的所有家庭
  Future<List<Household>> list() async {
    final result = await apiClient.get("/api/v1/households");

    final data = result['data'];
    if (data is! List) {
      throw const ApiException("家庭列表格式不正确");
    }

    try {
      return data
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException("家庭格式数据不正确");
            }
            return Household.fromJson(item);
          })
          .toList(growable: false);
    } on FormatException {
      throw const ApiException("家庭列表格式不正确");
    }
  }

  // 创建家庭并返回新家庭的id 后端创建接口目前返回Household数据库实体  获取role和memberCount等列表信息
  // 这里暂时只读取id 创建完成后重新请求list
  Future<int> create({required String name}) async {
    final result = await apiClient.post(
      "/api/v1/households",
      body: {"name": name.trim()},
    );

    final data = result['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException("创建家庭的返回数据格式不正确");
    }
    final id = data['id'];
    if (id is! num || id.toInt() <= 0) {
      throw const ApiException("创建家庭的返回数据格式不正确");
    }

    return id.toInt();
  }
}
