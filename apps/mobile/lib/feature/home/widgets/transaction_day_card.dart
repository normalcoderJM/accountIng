import 'package:flutter/material.dart';
import 'package:mobile/feature/home/transaction_day_group.dart';
import 'package:mobile/feature/home/widgets/transaction_tile.dart';
import 'package:mobile/feature/transaction/transaction.dart';

class TransactionDayCard extends StatelessWidget {
  const TransactionDayCard({
    super.key,
    required this.group,
    required this.onTransactionTap,
  });

  final TransactionDayGroup group;

  /// 用户点击某条账单时，把被点击的账单传给父页面。
  final ValueChanged<Transaction> onTransactionTap;

  String formatCents(int amount) {
    return (amount / 100).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final items = group.transactions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatGroupDate(group.date),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  "收 ￥${formatCents(group.income)}  "
                  "支 ￥${formatCents(group.expense)}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  TransactionTile(
                    transaction: items[index],
                    onTap: () {
                      onTransactionTap(items[index]);
                    },
                  ),
                  if (index < items.length - 1)
                    const Divider(height: 1, indent: 72),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
