
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shine_effect.dart';
import '../../widgets/animated_counter.dart';

// --- Insight Card (NEW) ---
class InsightCard extends StatelessWidget {
  final String text;
  final int index;

  const InsightCard({super.key, required this.text, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        // Clamp opacity to valid range
        final safeOpacity = value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - safeOpacity)),
          child: Opacity(
            opacity: safeOpacity,
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.lightbulb_fill, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Budget Ring Card (Refined) ---
class BudgetRingCard extends StatelessWidget {
  final double spent;
  final double budget;

  const BudgetRingCard({
    super.key,
    required this.spent,
    required this.budget, 
  });

  @override
  Widget build(BuildContext context) {
    if (budget <= 0) return const SizedBox.shrink(); // Prevent division by zero
    
    // Clamp progress to valid range and handle edge cases
    final progress = (spent / budget).clamp(0.0, 1.0);
    if (progress.isNaN || progress.isInfinite) {
      return const SizedBox.shrink();
    }

    String emoji;
    if (progress < 0.5) {
      emoji = '😌';
    } else if (progress < 0.8) {
      emoji = '🙂';
    } else {
      emoji = '😬';
    }

    return ShineEffect(
      child: GlassCard(
        color: AppColors.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly Budget', style: AppTextStyles.label.copyWith(fontSize: 14)),
                    const SizedBox(height: 4),
                    AnimatedCounter(
                      value: spent,
                      prefix: '₹',
                      style: AppTextStyles.h1.copyWith(fontSize: 36),
                    ),
                    Text(
                      'of ₹${budget.toStringAsFixed(0)}', 
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 14)
                    ),
                  ],
                ),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background
                      const CircularProgressIndicator(
                        value: 1.0,
                        color: AppColors.border,
                        strokeWidth: 10,
                      ),
                      // Progress
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeOutExpo,
                        builder: (context, value, _) {
                          // Clamp value to valid range for CircularProgressIndicator
                          final safeValue = value.clamp(0.0, 1.0);
                          Color color = const Color(0xFF34D399); // Mint Green
                          if (safeValue > 0.6) color = const Color(0xFFFBBF24); // Amber
                          if (safeValue > 0.9) color = const Color(0xFFF87171); // Red
                          
                          return CircularProgressIndicator(
                            value: safeValue,
                            color: color,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                          );
                        },
                      ),
                      Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Monthly Activity Chart (NEW) ---
class MonthlyActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const MonthlyActivityChart({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxAmount = data.map((d) => d['amount'] as double).reduce(max);
    final safeMax = maxAmount > 0 ? maxAmount : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Activity', style: AppTextStyles.h3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Last 6 months',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.asMap().entries.map((entry) {
               final index = entry.key;
               final d = entry.value;
              return _buildMonthBar(
                context,
                label: d['label'] as String,
                amount: d['amount'] as double,
                maxAmount: safeMax,
                isCurrentMonth: d['isCurrentMonth'] as bool? ?? false,
                index: index,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBar(BuildContext context, {
    required String label, 
    required double amount, 
    required double maxAmount, 
    required bool isCurrentMonth, 
    required int index
  }) {
    Color barColor = isCurrentMonth ? AppColors.primary : AppColors.chartInactive;

    return Expanded(
      child: Column(
        children: [
          // Amount label on top
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 1500 + (index * 150)),
            curve: Curves.easeOut,
            builder: (context, value, _) {
              // Clamp opacity to valid range
              final safeOpacity = value.clamp(0.0, 1.0);
              return Opacity(
                opacity: safeOpacity,
                child: Text(
                  amount > 0 ? '₹${(amount / 1000).toStringAsFixed(0)}K' : '₹0',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCurrentMonth ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Bar
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: amount / maxAmount),
            duration: Duration(milliseconds: 1200 + (index * 100)),
            curve: Curves.elasticOut,
            builder: (context, value, _) {
              return Container(
                width: 16,
                height: max(100 * value, 6), // Min height 6 for visibility
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(8),
                  gradient: isCurrentMonth ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.7),
                    ],
                  ) : null,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            label, 
            style: AppTextStyles.label.copyWith(
              color: isCurrentMonth ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            )
          ),
        ],
      ),
    );
  }
}

// --- Spending Trend Chart (Refined) ---
class SpendingTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const SpendingTrendChart({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxAmount = data.map((d) => d['amount'] as double).reduce(max);
    final safeMax = maxAmount > 0 ? maxAmount : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity', style: AppTextStyles.h3),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.asMap().entries.map((entry) {
               final index = entry.key;
               final d = entry.value;
              return _buildBar(
                context,
                label: d['label'] as String,
                amount: d['amount'] as double,
                maxAmount: safeMax,
                isToday: d['isToday'] as bool? ?? false,
                index: index,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, {required String label, required double amount, required double maxAmount, required bool isToday, required int index}) {
    // Determine color based on amount relative to max
    // High bars get a slightly more intense color
    Color barColor = isToday ? AppColors.primary : AppColors.chartInactive;

    return Expanded(
      child: Column(
        children: [
          // Bar
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: amount / maxAmount),
            duration: Duration(milliseconds: 1200 + (index * 100)),
            curve: Curves.elasticOut,
            builder: (context, value, _) {
              return Container(
                width: 12,
                height: max(120 * value, 4), // Min height 4 for visibility
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            label, 
            style: AppTextStyles.label.copyWith(
              color: isToday ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            )
          ),
        ],
      ),
    );
  }
}

// --- Category Breakdown Tile (Refined) ---
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

  String _getCategoryEmoji(String category) {
    final map = {
      'Food & Drink': '🍔',
      'Shopping': '🛍️',
      'Transport': '🚕',
      'Entertainment': '🎬',
      'Groceries': '🍎',
      'Bills': '⚡',
      'Health': '💊',
      'Education': '📚',
      'Others': '✨',
    };
    return map[category] ?? '✨';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _getCategoryEmoji(category),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        width: 100,
                        decoration: BoxDecoration(
                          color: AppColors.chartInactive,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: percentage / 100),
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeOut,
                        builder: (context, value, _) {
                          return Container(
                            height: 6,
                            width: 100 * value,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedCounter(
                  value: amount,
                  prefix: '₹',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}