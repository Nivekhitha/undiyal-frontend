import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_storage_service.dart';
import 'analytics_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriod = 0; // 0: Week, 1: Month
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  final double _monthlyBudget = 15000.0; // Simulated user budget

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await TransactionStorageService.getAllTransactions();
    if (mounted) {
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    // --- DATA CALCULATION ---
    final now = DateTime.now();
    final periodDuration = _selectedPeriod == 0 ? 7 : 30; // Days
    
    // Filter transactions for the selected period
    final periodTransactions = _transactions.where((t) {
      final difference = now.difference(t.date).inDays;
      return difference < periodDuration && difference >= 0;
    }).toList();

    final totalSpent = periodTransactions.fold(0.0, (sum, t) => sum + t.amount);

    // Prepare Chart Data
    List<Map<String, dynamic>> chartData = [];
    if (_selectedPeriod == 0) {
      // WEEKLY: Show last 7 days (Mon-Sun or relative)
      // We'll show last 7 days ending today
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayTransactions = periodTransactions.where((t) => 
          t.date.year == day.year && t.date.month == day.month && t.date.day == day.day
        );
        final dayTotal = dayTransactions.fold(0.0, (sum, t) => sum + t.amount);
        
        // Label: "M", "T", "W"...
        final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final label = weekdays[day.weekday - 1];
        
        chartData.add({
          'label': label,
          'amount': dayTotal,
          'isToday': i == 0,
        });
      }
    } else {
      // MONTHLY: Show last 4 weeks
      for (int i = 3; i >= 0; i--) {
         // Simplified 4-week split
         final weekStart = now.subtract(Duration(days: (i * 7) + 6));
         final weekEnd = now.subtract(Duration(days: i * 7));
         
         final weekTransactions = periodTransactions.where((t) => 
            t.date.isAfter(weekStart.subtract(const Duration(seconds: 1))) && 
            t.date.isBefore(weekEnd.add(const Duration(days: 1))) // Inclusiveish
         );
         
         final weekTotal = weekTransactions.fold(0.0, (sum, t) => sum + t.amount);
         
         chartData.add({
           'label': 'W${4-i}',
           'amount': weekTotal,
           'isToday': i == 0, // Highlight current week
         });
      }
    }

    // Category Breakdown
    final categoryTotals = <String, double>{};
    for (var t in periodTransactions) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));


    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Analytics', style: AppTextStyles.h1),
                    // Currency Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('INR', style: AppTextStyles.label),
                    ),
                  ],
                ),
              ),
            ),
            
            // Toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildToggle('Week', 0),
                      _buildToggle('Month', 1),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Budget Ring
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: BudgetRingCard(
                  spent: totalSpent,
                  budget: _selectedPeriod == 0 ? _monthlyBudget / 4 : _monthlyBudget,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SpendingTrendChart(data: chartData),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Category Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text('Breakdown', style: AppTextStyles.h3),
                    const Spacer(),
                    Text('Sort by date', style: AppTextStyles.caption), // Static for now
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Category List or Empty State
            sortedCategories.isEmpty 
             ? SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.all(40),
                   child: Column(
                     children: [
                       const Text('👀', style: TextStyle(fontSize: 48)),
                       const SizedBox(height: 16),
                       Text('No spending yet', style: AppTextStyles.h3),
                       const SizedBox(height: 8),
                       Text(
                         'Start tracking to see your insights.',
                         style: AppTextStyles.bodySecondary,
                         textAlign: TextAlign.center,
                       ),
                     ],
                   ),
                 ),
               )
             : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cat = sortedCategories[index];
                      final percentage = totalSpent > 0 ? (cat.value / totalSpent) * 100 : 0.0;
                      
                      // Staggered Animation Wrapper
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + (index * 100)),
                        curve: Curves.easeOutQuad,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: CategoryBreakdownTile(
                                  category: cat.key,
                                  amount: cat.value,
                                  percentage: percentage,
                                  onTap: () {},
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: sortedCategories.length,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String title, int index) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? CupertinoColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected 
              ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] 
              : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
