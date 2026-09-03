enum HouseholdRole {
  owner,
  admin,
  member,
  viewer;

  factory HouseholdRole.fromJson(Object? value) {
    return switch (value) {
      "owner" => HouseholdRole.owner,
      "admin" => HouseholdRole.admin,
      "member" => HouseholdRole.member,
      "viewer" => HouseholdRole.viewer,
      _ => throw const FormatException("家庭角色格式不正确"),
    };
  }

  // 当前角色是否可以新增 修改 删除账单
  bool get canWrite {
    return switch (this) {
      HouseholdRole.owner ||
      HouseholdRole.admin ||
      HouseholdRole.member => true,
      HouseholdRole.viewer => false,
    };
  }

  // 当前角色是否管理家庭成员
  bool get canManageMembers {
    return switch (this) {
      HouseholdRole.owner || HouseholdRole.admin => true,
      HouseholdRole.member || HouseholdRole.viewer => false,
    };
  }

  String get displayName {
    return switch (this) {
      HouseholdRole.owner => "拥有者",
      HouseholdRole.admin => "管理员",
      HouseholdRole.member => "家庭成员",
      HouseholdRole.viewer => "只读成员",
    };
  }
}

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.role,
    required this.memberCount,
    required this.createdAt,
  });

  final int id;
  final String name;
  final HouseholdRole role;
  final int memberCount;
  final DateTime createdAt;

  bool get canWrite => role.canWrite;
  bool get canManageMembers => role.canManageMembers;

  factory Household.fromJson(Map<String, dynamic> json) {
    final id = json["id"];
    final name = json["name"];
    final memberCount = json["memberCount"];
    final createdAt = json["createdAt"];

    if (id is! num ||
        id.toInt() <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        memberCount is! num ||
        memberCount.toInt() < 0 ||
        createdAt is! String) {
      throw const FormatException("家庭数据格式不正确");
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) {
      throw const FormatException("家庭创建时间格式不正确");
    }
    return Household(
      id: id.toInt(),
      name: name.trim(),
      role: HouseholdRole.fromJson(json["role"]),
      memberCount: memberCount.toInt(),
      createdAt: parsedCreatedAt,
    );
  }
}
