import "package:mobile/core/api_client.dart";
import "package:mobile/feature/household/household.dart";
import "package:mobile/feature/household/household_member.dart";

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

  // 创建家庭后直接返回当前用户可使用的家庭视图。
  Future<Household> create({required String name}) async {
    final result = await apiClient.post(
      "/api/v1/households",
      body: {"name": name.trim()},
    );

    final data = result['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException("创建家庭的返回数据格式不正确");
    }
    try {
      return Household.fromJson(data);
    } on FormatException {
      throw const ApiException("创建家庭的返回数据格式不正确");
    }
  }

  // 获取指定家庭的有效成员列表
  Future<List<HouseholdMember>> listMembers({required int householdId}) async {
    if (householdId <= 0) {
      throw const ApiException("家庭ID不正确");
    }
    final result = await apiClient.get(
      "/api/v1/households/$householdId/members",
    );
    final data = result["data"];

    if (data is! List) {
      throw const ApiException("家庭成员列表格式不正确");
    }
    try {
      return data
          .map<HouseholdMember>((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException("家庭成员列表格式不正确");
            }
            return HouseholdMember.fromJson(item);
          })
          .toList(growable: false);
    } on FormatException {
      throw const ApiException("家庭成员列表格式不正确");
    }
  }
}
