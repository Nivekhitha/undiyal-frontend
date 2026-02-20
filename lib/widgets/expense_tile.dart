



import 'package:flutter/cupertino.dart';
import '../models/transaction_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ExpenseTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const ExpenseTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Drink':
        return CupertinoIcons.car_detailed;
      case 'Shopping':
        return CupertinoIcons.bag;
      case 'Transport':
        return CupertinoIcons.car;
      case 'Entertainment':
        return CupertinoIcons.film;
      case 'Groceries':
        return CupertinoIcons.cart;
      case 'Bills':
        return CupertinoIcons.doc_text;
      case 'Health':
        return CupertinoIcons.heart;
      case 'Education':
        return CupertinoIcons.book;
      default:
        return CupertinoIcons.circle;
    }
  }

  String _displayMerchant(Transaction tx) {
    final m = tx.merchant.trim();
    if (m.isEmpty) return tx.type == 'credit' ? 'Bank Transfer' : 'Expense';
    final lower = m.toLowerCase();
    if (lower == 'a' || lower == 'a/c' || lower == 'ac') {
      return tx.type == 'credit' ? 'Bank Transfer' : m;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == 'credit';
    final merchantLabel = _displayMerchant(transaction);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCredit
                    ? const Color(0xFF10B981)
                        .withValues(alpha: 0.2) // Green for credit
                    : AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCredit
                    ? CupertinoIcons.arrow_down_circle
                    : _getCategoryIcon(transaction.category),
                color:
                    isCredit ? const Color(0xFF10B981) : AppColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchantLabel,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (transaction.isAutoDetected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCredit
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCredit ? 'Credit' : 'Auto',
                            style: AppTextStyles.label.copyWith(
                              fontSize: 10,
                              color: isCredit
                                  ? const Color(0xFF10B981)
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCredit ? 'Received' : transaction.category,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isCredit
                      ? '+₹${transaction.amount.toStringAsFixed(2)}'
                      : '-₹${transaction.amount.toStringAsFixed(2)}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCredit ? const Color(0xFF10B981) : AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.date),
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
