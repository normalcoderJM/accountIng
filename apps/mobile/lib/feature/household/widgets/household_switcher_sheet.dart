import "package:flutter/material.dart";
import "package:mobile/feature/household/household.dart";
import "package:mobile/theme/app_colors.dart";
import "package:mobile/theme/app_dimensions.dart";

// 打开家庭弹窗层 返回household 表示选择一个家庭 返回null 表示创建了一个家庭
Future<Household?> showHouseholdSwitcherSheet({
  required BuildContext context,
  required List<Household> households,
  required int selectedHouseholdId,
  required Future<void> Function() onCreateHousehold,
}) {
  return showModalBottomSheet<Household>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _HouseholdSwitcherSheet(
        households: households,
        selectedHouseholdId: selectedHouseholdId,
        onCreateHousehold: onCreateHousehold,
      );
    },
  );
}

class _HouseholdSwitcherSheet extends StatelessWidget {
  const _HouseholdSwitcherSheet({
    required this.households,
    required this.selectedHouseholdId,
    required this.onCreateHousehold,
  });

  final List<Household> households;
  final int selectedHouseholdId;
  final Future<void> Function() onCreateHousehold;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.extraLarge),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          // 顶部拖拽指示条
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const SizedBox(width: AppSize.minimumTapTarget),
                Expanded(
                  child: Text(
                    "切换家庭",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "关闭",
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: households.length,
              separatorBuilder: (_, _) {
                return const SizedBox(height: AppSpacing.sm);
              },
              itemBuilder: (context, index) {
                final household = households[index];
                final selected = household.id == selectedHouseholdId;
                return _HouseholdOption(
                  household: household,
                  selected: selected,
                  onTap: () {
                    Navigator.of(context).pop(household);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  // 先关闭底部弹层 再进入创建家庭页面
                  Navigator.of(context).pop();

                  await onCreateHousehold();
                },
                label: const Text("创建新家庭"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdOption extends StatelessWidget {
  const _HouseholdOption({
    required this.household,
    required this.selected,
    required this.onTap,
  });

  final Household household;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.outline;

    final backgroundColor = selected
        ? AppColors.primaryContainer
        : AppColors.surface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_rounded, color: Colors.white),
              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      household.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "${household.memberCount}位成员",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: Text(
                            household.role.displayName,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
