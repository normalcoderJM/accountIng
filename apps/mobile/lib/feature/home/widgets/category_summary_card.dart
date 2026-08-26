import "package:flutter/material.dart";
import "package:mobile/feature/transaction/transaction_summary.dart";

class CategorySummaryCard extends StatelessWidget {
  const CategorySummaryCard({
    super.key,
    required this.categories,
    required this.totalExpense,
  });
  final List<TransactionCategorySummary> categories;
  // 后端返回的当月总支出
  final int totalExpense;

  String formatCents(int amount) {
    return (amount / 100).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    // 创建一个新列表 避免排序时修改原始接口数据
    final expenseCategories =
        categories
            .where((item) => item.type == "expense" && item.amount > 0)
            .toList()
          ..sort((first, second) {
            return second.amount.compareTo(first.amount);
          });
    // 当前没有支出 不显示分类统计卡片
    if (expenseCategories.isEmpty || totalExpense <= 0) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "支出分类",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                "本月",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 横向滚动 分类较多时 不会把首页纵向空间占满
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final item = expenseCategories[index];
                final percentage = item.amount / totalExpense;
                return _CategoryItem(
                  category: item.category,
                  amountText: "￥${formatCents(item.amount)}",
                  percentage: percentage.clamp(0.0, 1.0).toDouble(),
                );
              },
              separatorBuilder: (context, index) {
                return const SizedBox(width: 10);
              },
              itemCount: expenseCategories.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.amountText,
    required this.percentage,
  });

  final String category;
  final String amountText;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final percentageText = "${(percentage * 100).toStringAsFixed(1)}%";
    return Container(
      width: 132,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                percentageText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            amountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percentage,
            minHeight: 4,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: colors.surfaceContainerHighest,
            color: colors.error,
          ),
        ],
      ),
    );
  }
}
