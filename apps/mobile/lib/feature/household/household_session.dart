import "dart:collection";

import "package:flutter/foundation.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/feature/household/household.dart";
import "package:mobile/feature/household/household_api.dart";
import "package:mobile/feature/household/selected_household_storage.dart";

// householdSession管理当前登录用户的家庭状态
// 它的声明周期和登录会话保持一致
// 登录成功--->加载家庭
// 切换家庭--->通知首页重新加载账单
// 退出登录--->清理家庭状态
class HouseholdSession extends ChangeNotifier {
  HouseholdSession({
    required HouseholdApi householdApi,
    required SelectedHouseholdStorage storage,
  }) : _householdApi = householdApi,
       _storage = storage;

  final HouseholdApi _householdApi;
  final SelectedHouseholdStorage _storage;

  List<Household> _households = const [];
  Household? _selectedHousehold;
  bool _loading = false;
  String? _errorMessage;

  // 使用unmodifiableLIstView 防止页面直接修改内部列表
  List<Household> get households {
    return UnmodifiableListView(_households);
  }

  Household? get selectedHousehold => _selectedHousehold;
  int? get selectedHouseholdId => _selectedHousehold?.id;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  bool get hasHouseholds => _households.isNotEmpty;

  // 加载家庭列表 并恢复上次选中的家庭
  Future<void> load() async {
    if (_loading) {
      return;
    }
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final loadedHouseholds = await _householdApi.list();
      final saveHouseholdId = await _storage.read();
      Household? selected;

      // 上次选择的家庭仍然存在 继续选择它
      if (saveHouseholdId != null) {
        for (final household in loadedHouseholds) {
          if (household.id == saveHouseholdId) {
            selected = household;
            break;
          }
        }
      }
      // 上次的家庭不存在或用户第一次登录 默认选择家庭列表中的第一个
      if (selected == null && loadedHouseholds.isNotEmpty) {
        selected = loadedHouseholds.first;
      }
      _households = loadedHouseholds;
      _selectedHousehold = selected;
      if (selected == null) {
        await _storage.clear();
      } else {
        await _storage.save(selected.id);
      }
    } on Object catch (error) {
      _errorMessage = switch (error) {
        ApiException exception => exception.message,
        _ => "加载家庭列表失败",
      };
      // 保留错误状态 同时继续向上抛出 aggGate需要处理UnauthorizedException
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // 切换当前家庭
  Future<void> select(Household household) async {
    final belongsToCurrentUser = _households.any(
      (item) => item.id == household.id,
    );
    if (!belongsToCurrentUser) {
      throw ArgumentError("无法选择不在当前家庭列表中的家庭");
    }
    if (_selectedHousehold?.id == household.id) {
      return;
    }
    // 先保存成功 再正式切换内存状态
    // 避免本地保存失败 界面显示成另外一个家庭
    await _storage.save(household.id);

    _selectedHousehold = household;
    notifyListeners();
  }

  // 创建家庭 并自动选择新创建的家庭
  Future<void> createAndSelect(String name) async {
    final normalizedName = name.trim();

    if (normalizedName.length < 2 || normalizedName.length > 40) {
      throw const ApiException("家庭名称长度必须在2-40字符之间");
    }

    final createdHousehold = await _householdApi.create(name: normalizedName);
    // 将新创建的列表变成一个不可修改的列表 只能用新数据替换旧数据 强制变更内存地址 驱使更新视图
    _households = List.unmodifiable([..._households, createdHousehold]);
    await select(createdHousehold);
  }

  // 退出登录时清理内存和本地选择
  Future<void> clear() async {
    _households = const [];
    _selectedHousehold = null;
    _errorMessage = null;
    _loading = false;
    await _storage.clear();
    notifyListeners();
  }
}
