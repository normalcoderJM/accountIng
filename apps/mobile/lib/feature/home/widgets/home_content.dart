import "package:flutter/material.dart";
import "package:mobile/feature/home/transaction_day_group.dart";
import "package:mobile/feature/home/widgets/category_summary_card.dart";
import "package:mobile/feature/home/widgets/home_summary.dart";
import "package:mobile/feature/home/widgets/month_selector.dart";
import "package:mobile/feature/home/widgets/transaction_day_card.dart";
import "package:mobile/feature/transaction/transaction.dart";
import "package:mobile/feature/transaction/transaction_summary.dart";

class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.scrollController,
    required this.selectedMonth,
    required this.monthLoading,
    required this.canGoNextMonth,
    required this.summary,
    required this.groups,
    required this.footer,
    required this.onRefresh,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onTransactionTap,
  });

  final ScrollController scrollController;
  final DateTime selectedMonth;
  final bool monthLoading;
  final TransactionSummary summary;
  final List<TransactionDayGroup> groups;
  final bool canGoNextMonth;

  // 分页加载中、分页失败、没有下一页等状态仍由homePage管理
  // homeContent只负责把footer放到正确位置
  final Widget footer;

  final Future<void> Function() onRefresh;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<Transaction> onTransactionTap;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: scrollController,
        // 即使当前月份没有账单 也允许用户下拉刷新
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: MonthSelector(
              selectedMonth: selectedMonth,
              onPrevious: onPreviousMonth,
              onNext: onNextMonth,
              canGoNext: canGoNextMonth,
              loading: monthLoading,
            ),
          ),
          SliverToBoxAdapter(
            child: HomeSummary(
              income: summary.income,
              expense: summary.expense,
              balance: summary.balance,
            ),
          ),
          SliverToBoxAdapter(
            child: CategorySummaryCard(
              categories: summary.categories,
              totalExpense: summary.expense,
            ),
          ),
          if (groups.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsetsGeometry.only(bottom: 80),
                  child: Text("暂无账单"),
                ),
              ),
            )
          else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final group = groups[index];
                return TransactionDayCard(
                  group: group,
                  onTransactionTap: onTransactionTap,
                );
              }, childCount: groups.length),
            ),
            SliverToBoxAdapter(child: footer),
          ],
        ],
      ),
    );
  }
}
