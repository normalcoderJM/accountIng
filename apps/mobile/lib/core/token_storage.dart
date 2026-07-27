// 负责保存 修改 删除token的类

import "package:shared_preferences/shared_preferences.dart";

class TokenStorage {
  static const _tokenKey = "auth_token";

  // 异步存token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // 异步读token app启动时调用
  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 异步清空token
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
