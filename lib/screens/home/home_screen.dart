import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../models/transaction_model.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/expense_tile.dart';
import '../../services/transaction_storage_service.dart';
import '../../services/app_init_service.dart';
import 'home_widgets.dart';
import '../add_expense/add_expense_screen.dart';
import '../transactions/transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    // 1. Load stored transactions first (fast)
    final transactions = await TransactionStorageService.getAllTransactions();
    if (mounted) {
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    }

    // 2. Schedule SMS scan for after the frame builds
    // This prevents the UI from freezing during initial render
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _runBackgroundSmsScan();
    });
  }

  Future<void> _runBackgroundSmsScan() async {
    // Check permission first without requesting to minimize disruption
    // Only request if we are sure we want to (or let AppInitService handle it gracefully)
    await AppInitService.initialize();
    
    // Refresh to show new transactions
    if (mounted) {
      final updatedTransactions = await TransactionStorageService.getAllTransactions();
      setState(() {
        _transactions = updatedTransactions;
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

    final recentTransactions = _transactions.take(3).toList();
    final weeklySpent = _transactions
        .where((t) => DateTime.now().difference(t.date).inDays <= 7)
        .fold(0.0, (sum, t) => sum + t.amount);

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
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getGreeting(), style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text('Welcome back!', style: AppTextStyles.h2),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to notifications
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          CupertinoIcons.bell,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Balance Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.screenPadding),
                child: BalanceCard(balance: 2450.75, weeklySpent: weeklySpent),
              ),
            ),

            // Weekly Expense Chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This Week', style: AppTextStyles.h3),
                    const SizedBox(height: 16),
                    const WeeklyExpenseChart(),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Recent Transactions Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Transactions', style: AppTextStyles.h3),
                    GestureDetector(
                      onTap: () {
                        // Navigate to full history (handled by tab bar)
                      },
                      child: Text(
                        'See All',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Recent Transactions List
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ExpenseTile(
                        transaction: recentTransactions[index],
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => TransactionDetailScreen(
                                transaction: recentTransactions[index],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                }, childCount: recentTransactions.length),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Add Expense CTA
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const AddExpenseScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.add_circled,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Expense',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }
}
