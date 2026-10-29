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
    required this.onMemberCountChanged,
  });
  final Household household;
  final HouseholdApi householdApi;
  // token失效时 由AppGate统一退出登录
  final Future<void> Function() onUnauthorized;
  final ValueChanged<int> onMemberCountChanged;

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

  Future<void> _openAddMemberDialog() async {
    final member = await showDialog<HouseholdMember>(
      context: context,
      builder:
          (context) => _AddMemberDialog(
            householdId: widget.household.id,
            householdApi: widget.householdApi,
            onUnauthorized: widget.onUnauthorized,
          ),
    );
    if (!mounted || member == null) return;

    setState(() {
      _members = [..._members, member];
    });
    widget.onMemberCountChanged(_members.length);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("${member.email} 已加入家庭")));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            0,
          ),
          child: _HouseholdSummaryCard(
            household: widget.household,
            memberCount: _members.length,
          ),
        ),
        if (widget.household.canManageMembers)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              0,
            ),
            child: FilledButton.icon(
              onPressed: _openAddMemberDialog,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text("添加成员"),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Text(
            "成员列表",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child:
              _members.isEmpty
                  ? const Center(child: Text("暂无家庭成员"))
                  : RefreshIndicator(
                    onRefresh: _loadMembers,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.page,
                      ),
                      itemCount: _members.length,
                      separatorBuilder:
                          (_, _) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        return _MemberCard(member: _members[index]);
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

class _HouseholdSummaryCard extends StatelessWidget {
  const _HouseholdSummaryCard({
    required this.household,
    required this.memberCount,
  });

  final Household household;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "家庭成员",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  "$memberCount 位成员 · 你是${household.role.displayName}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({
    required this.householdId,
    required this.householdApi,
    required this.onUnauthorized,
  });

  final int householdId;
  final HouseholdApi householdApi;
  final Future<void> Function() onUnauthorized;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final member = await widget.householdApi.addMember(
        householdId: widget.householdId,
        email: _emailController.text,
      );
      if (mounted) Navigator.of(context).pop(member);
    } on UnauthorizedException {
      if (mounted) Navigator.of(context).pop();
      await widget.onUnauthorized();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = "添加家庭成员失败");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? "";
    if (email.isEmpty) return "请输入成员邮箱";
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) {
      return "请输入有效的邮箱地址";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("添加家庭成员"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("目前只能添加已经注册的用户，加入后默认为家庭成员。"),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _emailController,
              enabled: !_submitting,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              validator: _validateEmail,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: "成员邮箱"),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text("取消"),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? "添加中..." : "添加"),
        ),
      ],
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
    final (chipBackground, chipForeground) = switch (member.role) {
      HouseholdRole.owner => (
        AppColors.primaryContainer,
        AppColors.primaryDark,
      ),
      HouseholdRole.viewer => (
        const Color(0xFFFFF1DC),
        const Color(0xFF825500),
      ),
      HouseholdRole.admin ||
      HouseholdRole.member => (AppColors.surfaceMuted, AppColors.textSecondary),
    };
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
                color: chipBackground,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                member.role.displayName,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: chipForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
