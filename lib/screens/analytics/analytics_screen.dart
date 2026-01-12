import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../models/transaction_model.dart';
import 'analytics_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriod = 0; // 0: Week, 1: Month

  @override
  Widget build(BuildContext context) {
    final transactions = Transaction.getDummyTransactions();

    // Calculate totals
    final weekTotal = transactions
        .where((t) => DateTime.now().difference(t.date).inDays <= 7)
        .fold(0.0, (sum, t) => sum + t.amount);

    final monthTotal = transactions
        .where((t) => DateTime.now().difference(t.date).inDays <= 30)
        .fold(0.0, (sum, t) => sum + t.amount);

    final currentTotal = _selectedPeriod == 0 ? weekTotal : monthTotal;
    final previousTotal =
        _selectedPeriod == 0 ? 380.0 : 1250.0; // Dummy previous period
    final percentageChange =
        ((currentTotal - previousTotal) / previousTotal) * 100;

    // Calculate category breakdown
    final categoryTotals = <String, double>{};
    for (var transaction in transactions) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.screenPadding,
                  16,
                  AppConstants.screenPadding,
                  16,
                ),
                child: Row(
                  children: [
                    Text(
                      'Analytics',
                      style: AppTextStyles.h2,
                    ),
                  ],
                ),
              ),
            ),

            // Period Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildPeriodButton('Week', 0),
                      ),
                      Expanded(
                        child: _buildPeriodButton('Month', 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Total Spending Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Spending',
                        style: AppTextStyles.cardBody.copyWith(
                          fontSize: 14,
                          color: AppColors.textOnCard.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '₹${currentTotal.toStringAsFixed(2)}',
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.textOnCard,
                          fontSize: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            percentageChange >= 0
                                ? CupertinoIcons.arrow_up_right
                                : CupertinoIcons.arrow_down_right,
                            color: percentageChange >= 0
                                ? AppColors.error
                                : AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${percentageChange.abs().toStringAsFixed(1)}%',
                            style: AppTextStyles.body.copyWith(
                              color: percentageChange >= 0
                                  ? AppColors.error
                                  : AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            percentageChange >= 0
                                ? 'more than last ${_selectedPeriod == 0 ? 'week' : 'month'}'
                                : 'less than last ${_selectedPeriod == 0 ? 'week' : 'month'}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textOnCard.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Spending Chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spending Trend',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 16),
                    SpendingTrendChart(
                      isWeekly: _selectedPeriod == 0,
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Category Breakdown
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Text(
                  'Category Breakdown',
                  style: AppTextStyles.h3,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Category List
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = sortedCategories[index];
                    final percentage = (category.value / currentTotal) * 100;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CategoryBreakdownTile(
                        category: category.key,
                        amount: category.value,
                        percentage: percentage,
                        onTap: () {
                          _showCategoryDetail(
                              context, category.key, category.value);
                        },
                      ),
                    );
                  },
                  childCount: sortedCategories.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, int index) {
    final isSelected = _selectedPeriod == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : CupertinoColors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color:
                  isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _showCategoryDetail(
      BuildContext context, String category, double amount) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              category,
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 8),
            Text(
              'Total spent: ₹${amount.toStringAsFixed(2)}',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 24),
            Text(
              'This category represents ${((amount / 295.79) * 100).toStringAsFixed(1)}% of your spending in this period.',
              style: AppTextStyles.body,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Close',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
