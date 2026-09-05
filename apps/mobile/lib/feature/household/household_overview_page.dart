import "package:flutter/material.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/feature/household/household.dart";
import "package:mobile/feature/household/household_api.dart";
import "package:mobile/feature/household/household_member.dart";
import "package:mobile/theme/app_colors.dart";
import "package:mobile/theme/app_dimensions.dart";

class HouseholdOverviewPage extends StatefulWidget {
  const HouseholdOverviewPage({
    super.key,
    required this.household,
    required this.householdApi,
    required this.onUnauthorized,
  });
  final Household household;
  final HouseholdApi householdApi;
  // token失效时 由AppGate统一退出登录
  final Future<void> Function() onUnauthorized;

  @override
  State<HouseholdOverviewPage> createState() => _HouseholdOverviewPageState();
}

class _HouseholdOverviewPageState extends State<HouseholdOverviewPage> {
  bool _loading = true;
  String? _errorMessage;
  List<HouseholdMember> _members = const [];

  @override
  void initState() {
    super.initState();
    // initStatue不能写成aysnc 再同步的initState调用异步方法即可
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final members = await widget.householdApi.listMembers(
        householdId: widget.household.id,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _members = members;
      });
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
