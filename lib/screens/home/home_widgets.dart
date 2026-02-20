import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

import '../../models/transaction_model.dart';
import 'package:intl/intl.dart';

class WeeklyExpenseChart extends StatelessWidget {
  final List<Transaction> transactions;

  const WeeklyExpenseChart({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate last 7 days
    final weekData = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      final dayName = DateFormat('E').format(date); // Mon, Tue, etc.

      // Sum transactions for this day
      final dailyAmount = transactions
          .where((t) =>
              t.type.toLowerCase() == 'expense' &&
              t.date.year == date.year &&
              t.date.month == date.month &&
              t.date.day == date.day)
          .fold(0.0, (sum, t) => sum + t.amount);

      return {
        'day': dayName,
        'amount': dailyAmount,
        'isToday': index == 6, // Last item is today
      };
    });

    // Find max amount for scaling (min 100 to avoid division by zero or huge bars for tiny amounts)
    final maxRec = weekData
        .map((d) => d['amount'] as double)
        .reduce((a, b) => a > b ? a : b);
    final maxAmount = maxRec > 100 ? maxRec : 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weekData.map((data) {
              return _buildBar(
                day: data['day'] as String,
                amount: data['amount'] as double,
                maxAmount: maxAmount,
                isToday: data['isToday'] as bool,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required String day,
    required double amount,
    required double maxAmount,
    required bool isToday,
  }) {
    final heightRatio = amount / maxAmount;
    // Cap height at 1.0 (100%) to prevent overflow if max calculation is slightly off
    final safeRatio = heightRatio > 1.0 ? 1.0 : heightRatio;

    // Max height 120, min visible height 4
    final barHeight = 120 * safeRatio;

    return Column(
      children: [
        // Amount label
        SizedBox(
          height: 20,
          child: Text(
            amount > 0
                ? '₹${amount > 999 ? '${(amount / 1000).toStringAsFixed(1)}k' : amount.toStringAsFixed(0)}'
                : '',
            style: AppTextStyles.label.copyWith(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Bar
        Container(
          width: 32,
          height: barHeight > 4 ? barHeight : 4,
          decoration: BoxDecoration(
            color: isToday ? AppColors.primary : AppColors.chartInactive,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        // Day label
        Text(
          day,
          style: AppTextStyles.label.copyWith(
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
