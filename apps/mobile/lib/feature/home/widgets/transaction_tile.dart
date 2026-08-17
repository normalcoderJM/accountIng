import 'package:flutter/material.dart';
import 'package:mobile/feature/home/transaction_day_group.dart';
import 'package:mobile/feature/transaction/transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final Transaction transaction;
  final VoidCallback onTap;

  String formatAmount(Transaction transaction) {
    final value = transaction.amount / 100;
    final sign = transaction.type == "expense" ? "-" : "+";

    return "$sign${value.toStringAsFixed(2)}";
  }

  // 为分类设置图标
  IconData categoryIcon(String category) {
    return switch (category) {
      "餐饮" => Icons.restaurant_rounded,
      "交通" => Icons.directions_bus_rounded,
      "住房" => Icons.home_rounded,
      "购物" => Icons.shopping_bag_rounded,
      "医疗" => Icons.medical_services_rounded,
      "娱乐" => Icons.sports_esports_rounded,
      "工资" => Icons.account_balance_wallet_rounded,
      "兼职" => Icons.work_rounded,
      "奖金" => Icons.emoji_events_rounded,
      "红包" => Icons.redeem_rounded,
      _ => Icons.category_rounded,
    };
  }

  // 账单item组件
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isExpense = transaction.type == "expense";
    final amountColor = isExpense ? colors.error : colors.primary;
    final iconBackground = amountColor.withValues(alpha: 0.12);
    final subtitle = transaction.note.isEmpty
        ? formatTransactionTime(transaction.createdAt)
        : "${formatTransactionTime(transaction.createdAt)} · ${transaction.note}";
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                categoryIcon(transaction.category),
                size: 22,
                color: amountColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.category,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatAmount(transaction),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
