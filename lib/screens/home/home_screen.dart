import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../models/transaction_model.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/expense_tile.dart';
import '../../services/transaction_storage_service.dart';
import '../../services/balance_sms_parser.dart';
import '../../services/sms_notification_listener.dart';
import 'home_widgets.dart';
import '../../screens/bank/bank_balance_setup_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import '../transactions/transaction_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Transaction> _transactions = [];
  double _bankBalance = 0.0;
  String _bankName = '';
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _balanceUpdateSubscription;
  StreamSubscription<Map<String, dynamic>>? _smsStreamSubscription;
  StreamSubscription<Transaction>? _expenseUpdateSubscription;
  StreamSubscription<Transaction>? _localAddSubscription;
  String _selectedTransactionType = 'expense'; // 'expense' or 'credit'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTransactions();
    _subscribeToBalanceUpdates();
    _subscribeToSmsStream();
    _subscribeToExpenseUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _balanceUpdateSubscription?.cancel();
    _smsStreamSubscription?.cancel();
    _expenseUpdateSubscription?.cancel();
    _localAddSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh balance when app comes back to foreground
      _refreshBalance();
    }
  }

  Future<void> _refreshBalance() async {
    final balanceData = await BalanceSmsParser.getLastBalance();
    if (mounted && balanceData != null) {
      setState(() {
        _bankBalance = balanceData['balance'] ?? 0.0;
        _bankName = BalanceSmsParser.getBankFullName(balanceData['bank'] ?? '');
      });
    }
  }

  void _subscribeToBalanceUpdates() {
    _balanceUpdateSubscription = BalanceSmsParser.onBalanceUpdate.listen((data) {
      if (mounted) {
        setState(() {
          _bankBalance = data['balance'] ?? 0.0;
          _bankName = BalanceSmsParser.getBankFullName(data['bank'] ?? '');
        });
        debugPrint('Balance auto-updated: ${data['bank']} - Rs.${data['balance']}');
      }
    });
  }

  Future<void> _loadTransactions() async {
    // 1. Load stored transactions first (fast)
    final transactions = await TransactionStorageService.getAllTransactions();
    
    // 2. Load bank balance from NOTIFICATION LISTENER only
    final balanceData = await BalanceSmsParser.getLastBalance();
    
    if (mounted) {
      setState(() {
        _transactions = transactions;
        if (balanceData != null) {
          _bankBalance = balanceData['balance'] ?? 0.0;
          _bankName = BalanceSmsParser.getBankFullName(balanceData['bank'] ?? '');
        }
        _isLoading = false;
      });
    }
    
    // NO SMS SCAN - only notification listener should handle real-time updates
  }

  /// Subscribe to SMS notification stream for real-time transaction updates
  void _subscribeToSmsStream() {
    final listener = SmsNotificationListener();
    _smsStreamSubscription = listener.smsStream.listen((smsData) async {
      debugPrint('📱 HomeScreen received SMS stream event');
      // Refresh transactions when new SMS is processed
      await _refreshTransactions();
    });
  }

  /// Subscribe to real-time expense updates
  void _subscribeToExpenseUpdates() {
    _expenseUpdateSubscription = SmsNotificationListener.onExpenseUpdate.listen((transaction) {
      debugPrint('🟢 Real-time expense event received: ${transaction.merchant} - ₹${transaction.amount}');
      if (mounted) {
        final exists = _transactions.any((t) => t.id == transaction.id);
        if (exists) return;
        setState(() {
          _transactions.insert(0, transaction); // Add newest transaction to top
        });
      }
    });

    // Also listen for manual/local transactions added elsewhere
    _localAddSubscription = TransactionStorageService.onTransactionAdded.listen((transaction) {
      debugPrint('🟡 Local transaction added: ${transaction.merchant} - ₹${transaction.amount}');
      if (mounted) {
        final exists = _transactions.any((t) => t.id == transaction.id);
        if (exists) return;
        setState(() {
          _transactions.insert(0, transaction);
        });
      }
    });
  }

  /// Refresh transactions from storage
  Future<void> _refreshTransactions() async {
    final transactions = await TransactionStorageService.getAllTransactions();
    if (mounted) {
      setState(() {
        _transactions = transactions;
      });
      debugPrint('✅ HomeScreen transactions refreshed: ${transactions.length} items');
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

    // Calculate dynamic values
    final balance = _bankBalance; // Default to 0 until bank balance is set up
    final weeklySpent = _transactions
        .where((t) => t.type == 'expense' && DateTime.now().difference(t.date).inDays <= 7)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    // Calculate weekly credits separately
    final weeklyCredits = _transactions
        .where((t) => t.type == 'credit' && DateTime.now().difference(t.date).inDays <= 7)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    // Filter transactions by type
    final expenseTransactions = _transactions.where((t) => t.type == 'expense').toList();
    final creditTransactions = _transactions.where((t) => t.type == 'credit').toList();
    final displayTransactions = _selectedTransactionType == 'expense' 
        ? expenseTransactions 
        : creditTransactions;
    final recentTransactions = displayTransactions.take(3).toList();

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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Navigate to bank setup for checking balance
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => BankBalanceSetupScreen(
                                    onComplete: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: CupertinoColors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                CupertinoIcons.creditcard,
                                color: AppColors.textPrimary,
                                size: 22,
                              ),
                            ),
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
                  ],
                ),
              ),
            ),

            // Balance Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.screenPadding),
                child: BalanceCard(
                  balance: balance, 
                  weeklySpent: weeklySpent, 
                  weeklyCredits: weeklyCredits,
                  bankName: _bankName
                ),
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
                    WeeklyExpenseChart(transactions: _transactions),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Recent Transactions Header with Segmented Control
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Transactions', style: AppTextStyles.h3),
                        GestureDetector(
                          onTap: () {
                            // Navigate to full history page
                            Navigator.of(context).push(
                              CupertinoPageRoute(builder: (context) => const TransactionListScreen()),
                            );
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
                    const SizedBox(height: 12),
                    // Segmented Control for Expense/Credit
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTransactionType = 'expense';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedTransactionType == 'expense'
                                      ? AppColors.primary
                                      : CupertinoColors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Expenses',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body.copyWith(
                                    color: _selectedTransactionType == 'expense'
                                        ? AppColors.textOnCard
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTransactionType = 'credit';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedTransactionType == 'credit'
                                      ? AppColors.primary
                                      : CupertinoColors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Credits',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body.copyWith(
                                    color: _selectedTransactionType == 'credit'
                                        ? AppColors.textOnCard
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

            // Add Expense CTA - REMOVED
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
