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
      setState(() {
        _errorMessage = "加载家庭成员失败";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.household.name)),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _RequestError(message: _errorMessage!, onRetry: _loadMembers);
    }
    if (_members.isEmpty) {
      return const Center(child: Text("暂无家庭成员"));
    }

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.page),
        itemCount: _members.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          return _MemberCard(member: _members[index]);
        },
      ),
    );
  }
}

class _RequestError extends StatelessWidget {
  const _RequestError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("重新加载"),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final HouseholdMember member;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.primary,
              child: Icon(Icons.person_outline),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    member.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                member.role.displayName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
