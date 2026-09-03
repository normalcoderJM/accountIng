import "package:shared_preferences/shared_preferences.dart";

// selectedHouseholdStorage只负责保存选中的家庭id
// 不在这里保存整个household对象 因为家庭名称、角色、成员数量都可能被后端进行修改
// app启动时应该重新请求家庭列表 只恢复选中的id
class SelectedHouseholdStorage {
  static const _selectedHouseholdIdKey = 'selected_household_id';

  Future<int?> read() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getInt(_selectedHouseholdIdKey);
  }

  Future<void> save(int householdId) async {
    if (householdId <= 0) {
      throw ArgumentError.value(householdId, "householdId", '家庭ID必须大于0');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_selectedHouseholdIdKey, householdId);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_selectedHouseholdIdKey);
  }
}
