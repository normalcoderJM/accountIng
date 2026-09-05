import "package:flutter/material.dart";
import "package:mobile/feature/household/widgets/household_hero_illustration.dart";
import "package:mobile/theme/app_colors.dart";
import "package:mobile/theme/app_dimensions.dart";

class HouseholdOnboardingPage extends StatelessWidget {
  const HouseholdOnboardingPage({
    super.key,
    required this.onCreateHousehold,
    this.onJoinWithInvitation,
    required this.onLogout,
  });
  // 点击创建家庭
  final VoidCallback onCreateHousehold;
  // 点击加入家庭
  final VoidCallback? onJoinWithInvitation;
  // 点击退出登录
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // sliverfillRemaining 内容较少时撑满屏幕 小屏幕内容放不下仍然可以滚动
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      "开始家庭记账",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "和家人一起记录每一笔收支",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Center(child: HouseholdHeroIllustration(width: 238)),
                    const SizedBox(height: AppSpacing.md),
                    const _BenefitCard(),
                    // 把按钮推到屏幕底部 再小屏幕上空间不足 customScrollView 仍可 滚动
                    const Spacer(),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: onCreateHousehold,
                      child: const Text("创建家庭"),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: onJoinWithInvitation,
                      child: const Text("通过邀请加入"),
                    ),
                    // 顶部标题栏
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        // ui稿目前没有退出按钮 但是这里必须补充业务出口 否则没有家庭的用户登录后将无法退出账号
        TextButton(
          onPressed: () async {
            await onLogout();
          },
          child: Text(
            "退出",
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// 这个组件只在当前文件使用 下划线定义为私有组件
class _BenefitCard extends StatelessWidget {
  const _BenefitCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          children: const [
            _BenefitItem(
              icon: Icons.group_outlined,
              title: "共同账单",
              description: "收支共享，账目清晰",
            ),
            Divider(),
            _BenefitItem(
              icon: Icons.pie_chart_outline,
              title: "家庭预算",
              description: "合理规划，控制支出",
            ),
            Divider(),
            _BenefitItem(
              icon: Icons.groups_2_outlined,
              title: "成员协作",
              description: "多人协作，分工管理",
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
