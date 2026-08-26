import "package:flutter/material.dart";

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.canGoNext,
    required this.loading,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsetsGeometry.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: loading ? null : onPrevious,
                icon: const Icon(Icons.chevron_left),
                tooltip: "上个月",
              ),
              Expanded(
                child: Text(
                  "${selectedMonth.year}年${selectedMonth.month}月",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: loading || !canGoNext ? null : onNext,
                icon: const Icon(Icons.chevron_right),
                tooltip: "下个月",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
