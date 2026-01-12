import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class WeeklyExpenseChart extends StatelessWidget {
  const WeeklyExpenseChart({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data for the week (Monday to Sunday)
    final weekData = [
      {'day': 'Mon', 'amount': 45.0},
      {'day': 'Tue', 'amount': 120.0},
      {'day': 'Wed', 'amount': 85.0},
      {'day': 'Thu', 'amount': 32.0},
      {'day': 'Fri', 'amount': 95.0},
      {'day': 'Sat', 'amount': 12.0},
      {'day': 'Sun', 'amount': 65.0},
    ];

    final maxAmount = weekData.map((d) => d['amount'] as double).reduce((a, b) => a > b ? a : b);

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
  }) {
    final heightRatio = amount / maxAmount;
    final barHeight = 120 * heightRatio;
    final isToday = day == _getCurrentDay();

    return Column(
      children: [
        // Amount label
        SizedBox(
          height: 20,
          child: Text(
            amount > 0 ? '₹${amount.toStringAsFixed(0)}' : '',
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
          height: barHeight > 20 ? barHeight : 20,
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

  String _getCurrentDay() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[DateTime.now().weekday - 1];
  }
}