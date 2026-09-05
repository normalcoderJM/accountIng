import "package:mobile/feature/household/household.dart";

class HouseholdMember {
  const HouseholdMember({
    required this.memberId,
    required this.userId,
    required this.email,
    required this.role,
    required this.joinedAt,
  });
  // household_member 表的主键 修改角色 移除家庭时使用这个id
  final int memberId;
  // user表的主键
  final int userId;
  final String email;
  final HouseholdRole role;
  final DateTime joinedAt;

  // 当前后端还没有用户昵称字段 暂时使用邮箱@前面的部分作为显示名称
  String get displayName {
    final atIndex = email.indexOf("@");

    if (atIndex <= 0) {
      return email;
    }
    return email.substring(0, atIndex);
  }

  bool get canWrite => role.canWrite;
  bool get canManageMembers => role.canManageMembers;

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    final memberId = json['memberId'];
    final userId = json['userId'];
    final email = json['email'];
    final joinedAt = json['joinedAt'];

    if (memberId is! num || memberId.toInt() <= 0) {
      throw const FormatException("家庭成员ID格式不正确");
    }

    if (userId is! num || userId.toInt() <= 0) {
      throw const FormatException("用户ID格式不正确");
    }

    if (email is! String || email.trim().isEmpty) {
      throw const FormatException("成员邮箱格式不正确");
    }

    if (joinedAt is! String) {
      throw const FormatException("加入家庭时间格式不正确");
    }

    final parsedJoinedAt = DateTime.tryParse(joinedAt);
    if (parsedJoinedAt == null) {
      throw const FormatException("加入家庭时间格式不正确");
    }

    return HouseholdMember(
      memberId: memberId.toInt(),
      userId: userId.toInt(),
      email: email.trim(),
      role: HouseholdRole.fromJson(json["role"]),
      joinedAt: parsedJoinedAt,
    );
  }
}
