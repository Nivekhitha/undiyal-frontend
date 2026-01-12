import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class SpendingTrendChart extends StatelessWidget {
  final bool isWeekly;

  const SpendingTrendChart({
    super.key,
    required this.isWeekly,
  });

  @override
  Widget build(BuildContext context) {
    final chartData = isWeekly ? _getWeeklyData() : _getMonthlyData();
    final maxAmount = chartData.map((d) => d['amount'] as double).reduce((a, b) => a > b ? a : b);

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
            children: chartData.map((data) {
              return _buildBar(
                label: data['label'] as String,
                amount: data['amount'] as double,
                maxAmount: maxAmount,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getWeeklyData() {
    return [
      {'label': 'Mon', 'amount': 45.0},
      {'label': 'Tue', 'amount': 120.0},
      {'label': 'Wed', 'amount': 85.0},
      {'label': 'Thu', 'amount': 32.0},
      {'label': 'Fri', 'amount': 95.0},
      {'label': 'Sat', 'amount': 12.0},
      {'label': 'Sun', 'amount': 65.0},
    ];
  }

  List<Map<String, dynamic>> _getMonthlyData() {
    return [
      {'label': 'W1', 'amount': 245.0},
      {'label': 'W2', 'amount': 320.0},
      {'label': 'W3', 'amount': 185.0},
      {'label': 'W4', 'amount': 295.0},
    ];
  }

  Widget _buildBar({
    required String label,
    required double amount,
    required double maxAmount,
  }) {
    final heightRatio = amount / maxAmount;
    final barHeight = 140 * heightRatio;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
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
              width: double.infinity,
              height: barHeight > 20 ? barHeight : 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            // Label
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryBreakdownTile extends StatelessWidget {
  final String category;
  final double amount;
  final double percentage;
  final VoidCallback onTap;

  const CategoryBreakdownTile({
    super.key,
    required this.category,
    required this.amount,
    required this.percentage,
    required this.onTap,
  });

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Drink':
        return CupertinoIcons.bag;
      case 'Shopping':
        return CupertinoIcons.bag_fill;
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food & Drink':
        return const Color(0xFFFFB6C1);
      case 'Shopping':
        return const Color(0xFFB8A9FF);
      case 'Transport':
        return const Color(0xFF9DD6FF);
      case 'Entertainment':
        return const Color(0xFFFFD19A);
      case 'Groceries':
        return const Color(0xFFA8E6A3);
      case 'Bills':
        return const Color(0xFFFFE4A0);
      case 'Health':
        return const Color(0xFFFFB3BA);
      case 'Education':
        return const Color(0xFFBAE1FF);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${percentage.toStringAsFixed(1)}% of total',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: AppColors.chartInactive,
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage / 100,
                      child: Container(
                        color: _getCategoryColor(category),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}