import "package:flutter/material.dart";

// AppColors 只定义产品颜色 不包含具体组件样式
// 页面中尽量不要到处直接写Color(0xFF246B4E) 佛走以后调整品牌色 需要修改大量文件
abstract final class AppColors {
  // 品牌主色 深森林绿
  static const primary = Color(0xFF246B4E);
  // 按钮按下 较深区域使用
  static const primaryDark = Color(0xFF18543B);
  // 淡绿色容器背景
  static const primaryContainer = Color(0xFFE3F1E8);
  // 页面暖白背景
  static const background = Color(0xFFFAF8F2);
  // 卡牌和输入框表面颜色
  static const surface = Color(0xFFFFFFFF);
  // 次级表面 用于浅色信息区域
  static const surfaceMuted = Color(0xFFF4F3EE);
  // 主要文字
  static const textPrimary = Color(0xFF20231F);
  // 次要说明文字
  static const textSecondary = Color(0xFF747970);
  // 边框和分割线
  static const outline = Color(0xFFDADDD6);
  // 更浅的分割线
  static const outlineSoft = Color(0xFFECEDE8);
  // 支出金额
  static const expense = Color(0xFFE85B47);
  // 收入金额
  static const income = Color(0xFF247A52);
  // 分类中的橙色强调色
  static const accentOrange = Color(0xFFF38A3D);
  // 错误状态
  static const error = Color(0xFFBA1A1A);
}
