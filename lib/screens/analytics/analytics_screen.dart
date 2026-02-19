
import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/analytics_service.dart';
import '../../services/settings_service.dart';
import 'analytics_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  
  // Data State
  double _totalSpent = 0;
  double _monthlyBudget = 5000;
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _monthlyData = [];
  Map<String, double> _categoryTotals = {};
  List<String> _insights = [];
  StreamSubscription<String>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Listen for settings changes and refresh
    _settingsSubscription = SettingsService.onSettingsChange.listen((settingKey) {
      if (settingKey == 'monthly_budget') {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await AnalyticsService.getAnalyticsData();
      final budget = await SettingsService.getMonthlyBudget();
      if (mounted) {
        setState(() {
          _totalSpent = (data['totalSpent'] as num).toDouble();
          _monthlyBudget = budget;
          
          // Safe List Casting
          _weeklyData = (data['weeklyData'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
          _monthlyData = (data['monthlyData'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
          
          // Safe Map Casting
          _categoryTotals = Map<String, double>.from(data['categoryTotals']);
          
          _insights = List<String>.from(data['insights']);
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Optionally handle error state
        });
      }
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

    final sortedCategories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Analytics', style: AppTextStyles.h1),
                    // Month Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('This Month', style: AppTextStyles.label),
                    ),
                  ],
                ),
              ),
            ),
            
            // 1. Budget Ring
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: BudgetRingCard(
                  spent: _totalSpent,
                  budget: _monthlyBudget,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 2. Insights Section (New)
            if (_insights.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Insights for you', style: AppTextStyles.h3),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return InsightCard(text: _insights[index], index: index);
                    },
                    childCount: _insights.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // 3. Monthly Activity Chart (NEW)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: MonthlyActivityChart(data: _monthlyData),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 4. Weekly Activity Chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SpendingTrendChart(data: _weeklyData),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 5. Category Breakdown
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('Spending by Category', style: AppTextStyles.h3),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

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
                         'Start tracking to see your stats!',
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
                      final percentage = _totalSpent > 0 ? (cat.value / _totalSpent) * 100 : 0.0;
                      
                      // Staggered Animation Wrapper
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + (index * 100)),
                        curve: Curves.easeOutQuad,
                        builder: (context, value, child) {
                          // Clamp opacity to valid range
                          final safeOpacity = value.clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - safeOpacity)),
                            child: Opacity(
                              opacity: safeOpacity,
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
}
