import 'package:flutter/material.dart';

class HomeSummary extends StatelessWidget {
  const HomeSummary({
    super.key,
    required this.income,
    required this.expense,
    required this.balance,
  });

  final int income;
  final int expense;
  final int balance;

  String formatCents(int amount) {
    return (amount / 100).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(label: "收入", value: "￥${formatCents(income)}"),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(label: "支出", value: "￥${formatCents(expense)}"),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(label: "结余", value: "￥${formatCents(balance)}"),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
