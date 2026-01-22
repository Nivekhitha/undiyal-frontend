import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shine_effect.dart';
import '../../widgets/animated_counter.dart';

// --- Budget Ring Card ---
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
    final progress = (spent / budget).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

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
        color: AppColors.primary.withOpacity(0.05), // Very subtle tint
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
                      // Background Circle
                      CircularProgressIndicator(
                        value: 1.0,
                        color: AppColors.border,
                        strokeWidth: 10,
                      ),
                      // Progress Circle
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeOutExpo,
                        builder: (context, value, _) {
                          Color color = AppColors.success;
                          if (value > 0.5) color = AppColors.warning;
                          if (value > 0.8) color = AppColors.error;
                          
                          return CircularProgressIndicator(
                            value: value,
                            color: color,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                          );
                        },
                      ),
                      // Emoji Center
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

// --- Spending Trend Chart (Upgraded) ---
class SpendingTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool animate;

  const SpendingTrendChart({
    super.key,
    required this.data,
    this.animate = true,
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
            color: AppColors.textPrimary.withOpacity(0.05),
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
            children: data.map((d) {
              return _buildBar(
                label: d['label'] as String,
                amount: d['amount'] as double,
                maxAmount: safeMax,
                isToday: d['isToday'] as bool? ?? false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBar({required String label, required double amount, required double maxAmount, bool isToday = false}) {
    return Expanded(
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: amount / maxAmount),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.elasticOut,
            builder: (context, value, _) {
              return Container(
                width: 12,
                height: 120 * value, // Max height
                decoration: BoxDecoration(
                  color: isToday ? AppColors.primary : AppColors.chartInactive,
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

// --- Category Breakdown Tile (Upgraded) ---
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
      'Transfers': '💸',
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