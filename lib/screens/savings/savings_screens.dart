import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../models/savings_model.dart';
import '../../models/transaction_model.dart';
import '../../data/savings_mock_data.dart';
import '../../services/savings_storage_service.dart';
import '../../services/transaction_storage_service.dart';
import '../../services/settings_service.dart';
import '../../services/ai_suggestions_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import 'create_goal_screen.dart';
import 'edit_goal_screen.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  CategoryBudget? _selectedCategory;

  final SavingsStorageService _storageService = SavingsStorageService();
  List<SavingsGoal> _goals = [];
  bool _isLoadingGoals = true;

  double _monthlyBudget = 0;
  double _totalSpent = 0;
  double _monthlySavingsTarget = 0;
  String _currencySymbol = '₹';
  List<CategoryBudget> _categoryBudgets = [];
  bool _isLoadingBudget = true;
  String? _aiSuggestions;
  bool _aiSuggestionsLoading = true;
  StreamSubscription<String>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadBudgetData();
    _loadAiSuggestions();
    
    // Listen for settings changes and refresh
    _settingsSubscription = SettingsService.onSettingsChange.listen((settingKey) {
      if (settingKey == 'monthly_budget' || 
          settingKey == 'monthly_savings_target' || 
          settingKey == 'category_budgets') {
        _loadBudgetData();
      }
    });
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoadingGoals = true);
    await Future.delayed(const Duration(milliseconds: 400));
    final goals = await _storageService.getSavingsGoals();
    setState(() {
      _goals = goals;
      _isLoadingGoals = false;
    });
  }

  Future<void> _loadBudgetData() async {
    setState(() => _isLoadingBudget = true);
    final budget = await SettingsService.getMonthlyBudget();
    final savingsTarget = await SettingsService.getMonthlySavingsTarget();
    final catBudgets = await SettingsService.getCategoryBudgets();
    final symbol = await SettingsService.getCurrencySymbol();
    final transactions = await TransactionStorageService.getAllTransactions();
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    double totalSpent = 0;
    final Map<String, double> spentByCategory = {};
    for (final tx in transactions) {
      if (tx.type == 'expense' && tx.date.isAfter(thisMonthStart.subtract(const Duration(days: 1)))) {
        totalSpent += tx.amount;
        spentByCategory[tx.category] = (spentByCategory[tx.category] ?? 0) + tx.amount;
      }
    }
    final List<CategoryBudget> list = [];
    for (final cat in AppConstants.categories) {
      final limit = catBudgets[cat] ?? 0;
      if (limit <= 0) continue;
      final spent = spentByCategory[cat] ?? 0;
      final remaining = (limit - spent).clamp(0.0, double.infinity);
      CategoryStatus status = CategoryStatus.onTrack;
      if (spent > limit) status = CategoryStatus.overspending;
      else if (spent / limit >= 0.8) status = CategoryStatus.warning;
      String suggestion = 'Keep tracking to stay within budget.';
      if (status == CategoryStatus.overspending) {
        suggestion = 'You\'re over budget. Review recent spending in this category.';
      } else if (status == CategoryStatus.warning) {
        suggestion = 'Approaching your limit. Consider reducing spending this month.';
      }
      list.add(CategoryBudget(
        id: cat,
        emoji: _getCategoryEmoji(cat),
        name: cat,
        budgetLimit: limit,
        spent: spent,
        remaining: remaining,
        status: status,
        suggestion: suggestion,
      ));
    }
    list.sort((a, b) => b.spent.compareTo(a.spent));
    if (mounted) {
      setState(() {
        _monthlyBudget = budget;
        _totalSpent = totalSpent;
        _monthlySavingsTarget = savingsTarget;
        _currencySymbol = symbol;
        _categoryBudgets = list;
        _isLoadingBudget = false;
      });
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'Food & Drink': return '🍕';
      case 'Shopping': return '🛒';
      case 'Transport': return '🚗';
      case 'Entertainment': return '🎬';
      case 'Groceries': return '🥕';
      case 'Bills': return '📄';
      case 'Health': return '🏥';
      case 'Education': return '📚';
      default: return '📦';
    }
  }

  Future<void> _loadAiSuggestions() async {
    setState(() => _aiSuggestionsLoading = true);
    final suggestions = await AiSuggestionsService.getSuggestions();
    if (mounted) {
      setState(() {
        _aiSuggestions = suggestions;
        _aiSuggestionsLoading = false;
      });
    }
  }

  BudgetOverview get _budgetOverview {
    final remaining = (_monthlyBudget - _totalSpent).clamp(0.0, double.infinity);
    final percentage = _monthlyBudget > 0 ? ((_totalSpent / _monthlyBudget) * 100).round() : 0;
    BudgetStatus status = BudgetStatus.onTrack;
    if (_totalSpent > _monthlyBudget) status = BudgetStatus.overspending;
    else if (percentage > 75) status = BudgetStatus.slightlyBehind;
    return BudgetOverview(
      monthlyBudget: _monthlyBudget,
      totalSpent: _totalSpent,
      remaining: remaining,
      percentage: percentage,
      status: status,
    );
  }

  String formatCurrency(double amount) {
    if (amount >= 100000) {
      final lakhs = amount / 100000;
      return '$_currencySymbol${lakhs % 1 == 0 ? lakhs.toStringAsFixed(0) : lakhs.toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      final k = amount / 1000;
      return '$_currencySymbol${k % 1 == 0 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}K';
    }
    return '$_currencySymbol${amount.toStringAsFixed(0)}';
  }

  String formatCurrencyFull(double amount) => '$_currencySymbol${amount.toStringAsFixed(0)}';

  Color getStatusColor(dynamic status) {
    if (status == BudgetStatus.onTrack || status == GoalStatus.onTrack || 
        status == GoalStatus.ahead || status == CategoryStatus.onTrack || 
        status == CheckinStatus.onTrack) {
      return const Color(0xFF10B981);
    }
    if (status == BudgetStatus.slightlyBehind || status == GoalStatus.behind || 
        status == CategoryStatus.warning || status == CheckinStatus.behind) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFEF4444);
  }

  Color getStatusBg(dynamic status) {
    if (status == BudgetStatus.onTrack || status == GoalStatus.onTrack || 
        status == GoalStatus.ahead || status == CategoryStatus.onTrack || 
        status == CheckinStatus.onTrack) {
      return const Color(0xFFD1FAE5);
    }
    if (status == BudgetStatus.slightlyBehind || status == GoalStatus.behind || 
        status == CategoryStatus.warning || status == CheckinStatus.behind) {
      return const Color(0xFFFEF3C7);
    }
    return const Color(0xFFFEE2E2);
  }

  String getStatusLabel(dynamic status) {
    if (status == BudgetStatus.onTrack || status == GoalStatus.onTrack || 
        status == CategoryStatus.onTrack || status == CheckinStatus.onTrack) {
      return 'On track';
    }
    if (status == BudgetStatus.slightlyBehind) return 'Slightly behind';
    if (status == BudgetStatus.overspending || status == CategoryStatus.overspending) {
      return 'Overspending';
    }
    if (status == GoalStatus.behind || status == CheckinStatus.behind) return 'Behind';
    if (status == GoalStatus.ahead) return 'Ahead';
    if (status == CategoryStatus.warning) return 'Warning';
    return '';
  }

  
  Future<void> _showDeleteConfirmation(SavingsGoal goal) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${goal.name}"? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _storageService.deleteSavingsGoal(goal.id);
      _loadGoals();
    }
  }

@override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              backgroundColor: const Color(0xFFF4F6F8),
              border: null,
              largeTitle: const Text('Savings'),
            ),
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                await Future.wait([
                  _loadBudgetData(),
                  _loadGoals(),
                  _loadAiSuggestions(),
                ]);
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildBudgetOverviewCard(),
                  const SizedBox(height: 24),
                  _buildSavingsGoalsSection(),
                  const SizedBox(height: 22),
                  _buildCategoryBudgetsSection(),
                  const SizedBox(height: 22),
                  _buildSmartSuggestionsSection(),
                  const SizedBox(height: 22),
                  _buildGoalInsightSection(),
                  const SizedBox(height: 22),
                  _buildRealTimeImpactSection(),
                  const SizedBox(height: 22),
                  _buildWeeklyCheckinSection(),
                  const SizedBox(height: 22),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetOverviewCard() {
    if (_isLoadingBudget) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const CupertinoActivityIndicator(),
      );
    }
    final overview = _budgetOverview;
    final statusColor = getStatusColor(overview.status);
    final isOverspending = overview.status == BudgetStatus.overspending;
    
    Color progressColor;
    if (isOverspending) {
      progressColor = AppColors.error;
    } else if (overview.percentage > 75) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.success;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
            Color(0xFF1976D2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1D3A).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.money_dollar, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'This Month\'s Budget',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              text: formatCurrencyFull(overview.totalSpent),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              children: [
                TextSpan(
                  text: ' of ${formatCurrencyFull(overview.monthlyBudget)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Container(
              height: 10,
              color: Colors.white.withOpacity(0.15),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: overview.percentage / 100,
                child: Container(color: progressColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: getStatusBg(overview.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      overview.status == BudgetStatus.onTrack
                          ? CupertinoIcons.arrow_up_right
                          : CupertinoIcons.arrow_down_right,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      getStatusLabel(overview.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatCurrencyFull(overview.remaining)} left',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Saving Goals',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CreateGoalScreen()),
                );
                await _loadGoals();
              },
              child: Row(
                children: [
                  Icon(CupertinoIcons.add, size: 14, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Add Goals',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: _goals.asMap().entries.map((entry) {
              final index = entry.key;
              final goal = entry.value;
              return Column(
                children: [
                  _buildGoalCard(goal),
                  if (index < _goals.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 78),
                      child: Container(height: 1, color: const Color(0xFFE2E8F0)),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard(SavingsGoal goal) {
    final percentage = goal.percentage.round();
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => EditGoalScreen(goal: goal),
          ),
        );
        if (result == true) {
          _loadGoals();
        }
      },
      onLongPress: () {
        _showDeleteConfirmation(goal);
      },
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _buildCircularProgress(
            percentage: percentage.toDouble(),
            color: _parseColor(goal.iconBorder),
            size: 64,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _parseColor(goal.iconBg),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(goal.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${goal.name} ${goal.emoji}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  goal.targetDate == 'no timeline' ? 'no timeline' : 'Target: ${goal.targetDate}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        children: [
                          TextSpan(
                            text: formatCurrency(goal.savedAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const TextSpan(text: ' Saved'),
                        ],
                      ),
                    ),
                    const Text(' · ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        children: [
                          TextSpan(
                            text: formatCurrency(goal.toGo),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const TextSpan(text: ' To Go'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(CupertinoIcons.pencil, size: 16, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCircularProgress({
    required double percentage,
    required Color color,
    required double size,
    required Widget child,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 3.5,
              backgroundColor: const Color(0xFFE8ECF1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Widget _buildCategoryBudgetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.arrow_up_right, size: 18, color: Colors.blue[900]),
            const SizedBox(width: 8),
            const Text(
              'Category Budgets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: _categoryBudgets.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Set category budgets in Profile → Savings Settings to see progress here.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: _categoryBudgets.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    return Column(
                      children: [
                        _buildCategoryCard(category),
                        if (index < _categoryBudgets.length - 1)
                          Container(
                            height: 1,
                            color: AppColors.border,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                          ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryBudget category) {
    final percentage = category.percentage.round();
    final statusColor = getStatusColor(category.status);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    _showTipModal(category);
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      CupertinoIcons.lightbulb,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCurrencyFull(category.budgetLimit),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            color: const Color(0xFFE8ECF1),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: math.min(percentage / 100, 1.0),
              child: Container(color: statusColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${formatCurrencyFull(category.spent)} spent',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            Text(
              '${formatCurrencyFull(category.remaining)} left',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTipModal(CategoryBudget category) {
    final statusColor = getStatusColor(category.status);
    final statusBg = getStatusBg(category.status);

    showCupertinoDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.lightbulb, size: 20, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Text(
                          '${category.emoji} ${category.name}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(CupertinoIcons.xmark, size: 20, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${getStatusLabel(category.status)} — ${formatCurrencyFull(category.spent)} of ${formatCurrencyFull(category.budgetLimit)} used',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Saving Tip',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category.suggestion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B3A6B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Got it',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.lightbulb, size: 18, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            const Text(
              'Smart Suggestions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_aiSuggestionsLoading)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          )
        else if (_aiSuggestions != null && _aiSuggestions!.isNotEmpty)
          _buildAiSuggestionsCard(_aiSuggestions!)
        else
          ...smartSuggestions.map((suggestion) => _buildSuggestionCard(suggestion)),
      ],
    );
  }

  Widget _buildAiSuggestionsCard(String markdown) {
    // Simple formatting: replace \n with newlines, strip ** for cleaner display
    final text = markdown.replaceAll(r'\n', '\n').replaceAll('**', '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.lightbulb, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                'AI-powered tips for you',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(SmartSuggestion suggestion) {
    Color diffColor;
    Color diffBg;
    
    switch (suggestion.difficulty) {
      case Difficulty.easy:
        diffColor = const Color(0xFF10B981);
        diffBg = const Color(0xFFD1FAE5);
        break;
      case Difficulty.medium:
        diffColor = const Color(0xFFF59E0B);
        diffBg = const Color(0xFFFEF3C7);
        break;
      case Difficulty.hard:
        diffColor = const Color(0xFFEF4444);
        diffBg = const Color(0xFFFEE2E2);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.lightbulb, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: diffBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  suggestion.difficulty.toString().split('.').last.capitalize(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: diffColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.explanation,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated savings',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
                Text(
                  formatCurrencyFull(suggestion.estimatedSavings),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CreateGoalScreen()),
                );
                await _loadGoals();
              },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B3A6B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Apply',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CreateGoalScreen()),
                );
                await _loadGoals();
              },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Dismiss',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalInsightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.link, size: 18, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text(
              'Goal Insight',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: Colors.blue[600]!, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🎯', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  goalInsight.message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRealTimeImpactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.bolt, size: 18, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            const Text(
              'Real-Time Impact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Daily Plan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrencyFull(dailySpending.planned),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Actual',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrencyFull(dailySpending.actual),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.arrow_down_right, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'At this rate, you may exceed your budget by ${formatCurrencyFull(dailySpending.predictedOvershoot)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDC2626),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyCheckinSection() {
    final checkin = weeklyCheckin;
    final statusColor = getStatusColor(checkin.status);
    final statusBg = getStatusBg(checkin.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.checkmark_alt_circle, size: 18, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            const Text(
              'Weekly Check-in',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Target',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatCurrencyFull(checkin.weeklyTarget),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Saved',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatCurrencyFull(checkin.actualSavings),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      getStatusLabel(checkin.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (checkin.recoverySuggestion != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.lightbulb, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          checkin.recoverySuggestion!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CreateGoalScreen()),
                );
                await _loadGoals();
              },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A6B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.add, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Add Expense',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CreateGoalScreen()),
                );
                await _loadGoals();
              },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.eye, size: 18, color: Colors.blue[900]),
                  const SizedBox(width: 6),
                  Text(
                    'All Tips',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}